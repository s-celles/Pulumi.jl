// pulumi-language-julia is the Pulumi language host for Julia programs.
//
// NOTE: This is a community-developed Julia SDK for Pulumi. It is NOT an official
// product of Pulumi Corporation.
package main

import (
	"bytes"
	"context"
	"encoding/json"
	"flag"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"strings"

	pbempty "google.golang.org/protobuf/types/known/emptypb"

	"github.com/pulumi/pulumi/sdk/v3/go/common/util/cmdutil"
	"github.com/pulumi/pulumi/sdk/v3/go/common/util/logging"
	"github.com/pulumi/pulumi/sdk/v3/go/common/util/rpcutil"
	"github.com/pulumi/pulumi/sdk/v3/go/common/version"
	pulumirpc "github.com/pulumi/pulumi/sdk/v3/proto/go"
	"google.golang.org/grpc"
)

// juliaLanguageHost implements the LanguageRuntimeServer interface for Julia.
type juliaLanguageHost struct {
	pulumirpc.UnimplementedLanguageRuntimeServer

	engineAddress string
	tracing       string
}

func main() {
	var tracing string
	var root string
	flag.StringVar(&tracing, "tracing", "", "Emit tracing to a Zipkin-compatible tracing endpoint")
	flag.StringVar(&root, "root", "", "Project root path")
	flag.Parse()

	args := flag.Args()
	if len(args) == 0 {
		cmdutil.Exit(fmt.Errorf("missing required engine RPC address argument"))
		return
	}
	engineAddress := args[0]

	// Fire up a gRPC server, letting the kernel choose a free port.
	port, done, err := rpcutil.Serve(0, nil, []func(*grpc.Server) error{
		func(srv *grpc.Server) error {
			host := newJuliaLanguageHost(engineAddress, tracing)
			pulumirpc.RegisterLanguageRuntimeServer(srv, host)
			return nil
		},
	}, nil)
	if err != nil {
		cmdutil.Exit(fmt.Errorf("could not start language host RPC server: %w", err))
		return
	}

	// Otherwise, print out the port so that the spawner knows how to reach us.
	fmt.Printf("%d\n", port)

	// And finally wait for the server to stop serving.
	if err := <-done; err != nil {
		cmdutil.Exit(fmt.Errorf("language host RPC server stopped with error: %w", err))
	}
}

func newJuliaLanguageHost(engineAddress, tracing string) *juliaLanguageHost {
	return &juliaLanguageHost{
		engineAddress: engineAddress,
		tracing:       tracing,
	}
}

// GetRequiredPlugins computes the complete set of anticipated plugins required by a program.
func (host *juliaLanguageHost) GetRequiredPlugins(
	ctx context.Context,
	req *pulumirpc.GetRequiredPluginsRequest,
) (*pulumirpc.GetRequiredPluginsResponse, error) {
	logging.V(5).Infof("GetRequiredPlugins: program=%s", req.GetProgram())

	// For now, we don't analyze the Julia program to extract required plugins.
	// Users should ensure required providers are installed.
	// In the future, we could parse Project.toml or main.jl for provider references.
	return &pulumirpc.GetRequiredPluginsResponse{
		Plugins: []*pulumirpc.PluginDependency{},
	}, nil
}

// Run executes a Julia program and returns the result.
func (host *juliaLanguageHost) Run(
	ctx context.Context,
	req *pulumirpc.RunRequest,
) (*pulumirpc.RunResponse, error) {
	logging.V(5).Infof("Run: program=%s, pwd=%s", req.GetProgram(), req.GetPwd())

	config, err := host.constructConfig(req)
	if err != nil {
		return nil, fmt.Errorf("failed to construct config: %w", err)
	}

	configSecretKeys, err := host.constructConfigSecretKeys(req)
	if err != nil {
		return nil, fmt.Errorf("failed to construct config secret keys: %w", err)
	}

	// Determine the program to run
	program := req.GetProgram()
	if program == "" {
		program = "."
	}

	// Find the main.jl file
	var mainFile string
	if info, err := os.Stat(program); err == nil && info.IsDir() {
		mainFile = filepath.Join(program, "main.jl")
	} else if strings.HasSuffix(program, ".jl") {
		mainFile = program
	} else {
		mainFile = filepath.Join(program, "main.jl")
	}

	// Check if main.jl exists
	if _, err := os.Stat(mainFile); os.IsNotExist(err) {
		return &pulumirpc.RunResponse{
			Error: fmt.Sprintf("could not find Julia program: %s", mainFile),
		}, nil
	}

	// Build the Julia command
	args := []string{
		"--project=.",
		"-e",
		fmt.Sprintf(`include("%s")`, filepath.Base(mainFile)),
	}

	cmd := exec.CommandContext(ctx, "julia", args...)
	cmd.Dir = filepath.Dir(mainFile)

	// Set up environment
	cmd.Env = os.Environ()
	cmd.Env = append(cmd.Env, fmt.Sprintf("PULUMI_PROJECT=%s", req.GetProject()))
	cmd.Env = append(cmd.Env, fmt.Sprintf("PULUMI_STACK=%s", req.GetStack()))
	cmd.Env = append(cmd.Env, fmt.Sprintf("PULUMI_DRY_RUN=%t", req.GetDryRun()))
	cmd.Env = append(cmd.Env, fmt.Sprintf("PULUMI_PARALLEL=%d", req.GetParallel()))
	cmd.Env = append(cmd.Env, fmt.Sprintf("PULUMI_MONITOR=%s", req.GetMonitorAddress()))
	cmd.Env = append(cmd.Env, fmt.Sprintf("PULUMI_ENGINE=%s", host.engineAddress))
	cmd.Env = append(cmd.Env, fmt.Sprintf("PULUMI_CONFIG=%s", config))
	cmd.Env = append(cmd.Env, fmt.Sprintf("PULUMI_CONFIG_SECRET_KEYS=%s", configSecretKeys))

	if req.GetOrganization() != "" {
		cmd.Env = append(cmd.Env, fmt.Sprintf("PULUMI_ORGANIZATION=%s", req.GetOrganization()))
	}

	// Capture output
	var stdout, stderr bytes.Buffer
	cmd.Stdout = io.MultiWriter(os.Stdout, &stdout)
	cmd.Stderr = io.MultiWriter(os.Stderr, &stderr)

	// Run the program
	if err := cmd.Run(); err != nil {
		if exitErr, ok := err.(*exec.ExitError); ok {
			// Return the error message from stderr if available
			errMsg := strings.TrimSpace(stderr.String())
			if errMsg == "" {
				errMsg = fmt.Sprintf("Julia program exited with code %d", exitErr.ExitCode())
			}
			return &pulumirpc.RunResponse{
				Error: errMsg,
			}, nil
		}
		return nil, fmt.Errorf("failed to run Julia program: %w", err)
	}

	return &pulumirpc.RunResponse{}, nil
}

// constructConfig creates a JSON string of configuration values.
func (host *juliaLanguageHost) constructConfig(req *pulumirpc.RunRequest) (string, error) {
	configMap := make(map[string]string)
	for k, v := range req.GetConfig() {
		configMap[k] = v
	}
	configJSON, err := json.Marshal(configMap)
	if err != nil {
		return "", err
	}
	return string(configJSON), nil
}

// constructConfigSecretKeys creates a JSON array of secret key names.
func (host *juliaLanguageHost) constructConfigSecretKeys(req *pulumirpc.RunRequest) (string, error) {
	secretKeys := req.GetConfigSecretKeys()
	if secretKeys == nil {
		secretKeys = []string{}
	}
	keysJSON, err := json.Marshal(secretKeys)
	if err != nil {
		return "", err
	}
	return string(keysJSON), nil
}

// GetPluginInfo returns information about the language plugin.
func (host *juliaLanguageHost) GetPluginInfo(
	ctx context.Context,
	req *pbempty.Empty,
) (*pulumirpc.PluginInfo, error) {
	return &pulumirpc.PluginInfo{
		Version: version.Version,
	}, nil
}

// InstallDependencies installs Julia package dependencies.
func (host *juliaLanguageHost) InstallDependencies(
	req *pulumirpc.InstallDependenciesRequest,
	server pulumirpc.LanguageRuntime_InstallDependenciesServer,
) error {
	logging.V(5).Infof("InstallDependencies: directory=%s", req.GetDirectory())

	directory := req.GetDirectory()
	if directory == "" {
		directory = "."
	}

	// Check for Project.toml
	projectToml := filepath.Join(directory, "Project.toml")
	if _, err := os.Stat(projectToml); os.IsNotExist(err) {
		// No Project.toml, nothing to install
		return nil
	}

	// Run Julia's Pkg.instantiate() to install dependencies
	cmd := exec.Command("julia", "--project=.", "-e", "using Pkg; Pkg.instantiate()")
	cmd.Dir = directory

	// Stream stdout
	stdout, err := cmd.StdoutPipe()
	if err != nil {
		return fmt.Errorf("failed to get stdout pipe: %w", err)
	}
	stderr, err := cmd.StderrPipe()
	if err != nil {
		return fmt.Errorf("failed to get stderr pipe: %w", err)
	}

	if err := cmd.Start(); err != nil {
		return fmt.Errorf("failed to start Julia: %w", err)
	}

	// Stream output to the server
	go func() {
		buf := make([]byte, 1024)
		for {
			n, err := stdout.Read(buf)
			if n > 0 {
				server.Send(&pulumirpc.InstallDependenciesResponse{
					Stdout: buf[:n],
				})
			}
			if err != nil {
				break
			}
		}
	}()

	go func() {
		buf := make([]byte, 1024)
		for {
			n, err := stderr.Read(buf)
			if n > 0 {
				server.Send(&pulumirpc.InstallDependenciesResponse{
					Stderr: buf[:n],
				})
			}
			if err != nil {
				break
			}
		}
	}()

	if err := cmd.Wait(); err != nil {
		return fmt.Errorf("Julia package installation failed: %w", err)
	}

	return nil
}

// RuntimeOptionsPrompts returns a list of additional prompts to ask during `pulumi new`.
func (host *juliaLanguageHost) RuntimeOptionsPrompts(
	ctx context.Context,
	req *pulumirpc.RuntimeOptionsRequest,
) (*pulumirpc.RuntimeOptionsResponse, error) {
	return &pulumirpc.RuntimeOptionsResponse{
		Prompts: []*pulumirpc.RuntimeOptionPrompt{},
	}, nil
}

// About returns information about the runtime for this language.
func (host *juliaLanguageHost) About(
	ctx context.Context,
	req *pulumirpc.AboutRequest,
) (*pulumirpc.AboutResponse, error) {
	// Get Julia version
	cmd := exec.Command("julia", "--version")
	output, err := cmd.Output()
	juliaVersion := "unknown"
	if err == nil {
		juliaVersion = strings.TrimSpace(string(output))
	}

	return &pulumirpc.AboutResponse{
		Executable: "julia",
		Version:    juliaVersion,
	}, nil
}

// GetProgramDependencies returns the set of dependencies required by the program.
func (host *juliaLanguageHost) GetProgramDependencies(
	ctx context.Context,
	req *pulumirpc.GetProgramDependenciesRequest,
) (*pulumirpc.GetProgramDependenciesResponse, error) {
	logging.V(5).Infof("GetProgramDependencies: program=%s", req.GetProgram())

	// For now, return empty. In the future, we could parse Project.toml
	// to return Julia package dependencies.
	return &pulumirpc.GetProgramDependenciesResponse{
		Dependencies: []*pulumirpc.DependencyInfo{},
	}, nil
}

// RunPlugin executes a plugin program and returns its output.
func (host *juliaLanguageHost) RunPlugin(
	req *pulumirpc.RunPluginRequest,
	server pulumirpc.LanguageRuntime_RunPluginServer,
) error {
	logging.V(5).Infof("RunPlugin: program=%s", req.GetProgram())

	// Build command
	args := []string{"--project=.", req.GetProgram()}
	args = append(args, req.GetArgs()...)

	cmd := exec.Command("julia", args...)
	cmd.Dir = req.GetPwd()
	cmd.Env = append(os.Environ(), req.GetEnv()...)

	stdout, err := cmd.StdoutPipe()
	if err != nil {
		return err
	}
	stderr, err := cmd.StderrPipe()
	if err != nil {
		return err
	}

	if err := cmd.Start(); err != nil {
		return err
	}

	// Stream output
	go func() {
		buf := make([]byte, 1024)
		for {
			n, err := stdout.Read(buf)
			if n > 0 {
				server.Send(&pulumirpc.RunPluginResponse{
					Output: &pulumirpc.RunPluginResponse_Stdout{Stdout: buf[:n]},
				})
			}
			if err != nil {
				break
			}
		}
	}()

	go func() {
		buf := make([]byte, 1024)
		for {
			n, err := stderr.Read(buf)
			if n > 0 {
				server.Send(&pulumirpc.RunPluginResponse{
					Output: &pulumirpc.RunPluginResponse_Stderr{Stderr: buf[:n]},
				})
			}
			if err != nil {
				break
			}
		}
	}()

	if err := cmd.Wait(); err != nil {
		if exitErr, ok := err.(*exec.ExitError); ok {
			server.Send(&pulumirpc.RunPluginResponse{
				Output: &pulumirpc.RunPluginResponse_Exitcode{Exitcode: int32(exitErr.ExitCode())},
			})
			return nil
		}
		return err
	}

	server.Send(&pulumirpc.RunPluginResponse{
		Output: &pulumirpc.RunPluginResponse_Exitcode{Exitcode: 0},
	})
	return nil
}

// GenerateProgram generates a Julia program from PCL (Pulumi Configuration Language).
func (host *juliaLanguageHost) GenerateProgram(
	ctx context.Context,
	req *pulumirpc.GenerateProgramRequest,
) (*pulumirpc.GenerateProgramResponse, error) {
	// Not implemented for Julia yet
	return nil, fmt.Errorf("GenerateProgram not implemented for Julia")
}

// GenerateProject generates a Julia project from PCL.
func (host *juliaLanguageHost) GenerateProject(
	ctx context.Context,
	req *pulumirpc.GenerateProjectRequest,
) (*pulumirpc.GenerateProjectResponse, error) {
	// Not implemented for Julia yet
	return nil, fmt.Errorf("GenerateProject not implemented for Julia")
}

// GeneratePackage generates a Julia package from a schema.
func (host *juliaLanguageHost) GeneratePackage(
	ctx context.Context,
	req *pulumirpc.GeneratePackageRequest,
) (*pulumirpc.GeneratePackageResponse, error) {
	// Not implemented for Julia yet
	return nil, fmt.Errorf("GeneratePackage not implemented for Julia")
}

// Pack packs a Julia package.
func (host *juliaLanguageHost) Pack(
	ctx context.Context,
	req *pulumirpc.PackRequest,
) (*pulumirpc.PackResponse, error) {
	// Not implemented for Julia yet
	return nil, fmt.Errorf("Pack not implemented for Julia")
}
