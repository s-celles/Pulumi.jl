module pulumirpc

include("../google/google.jl")
import .pulumirpc as var"#pulumirpc"

include("plugin_pb.jl")
include("source_pb.jl")
include("engine_pb.jl")
include("alias_pb.jl")
include("callback_pb.jl")
include("provider_pb.jl")
include("codegen/codegen.jl")
include("language_pb.jl")
include("resource_pb.jl")

end # module pulumirpc
