"""
Log severity levels for Pulumi engine communication.

Per constitution's Enum Convention: module-scoped with type T and SCREAMING_SNAKE_CASE values.

# Usage
```julia
severity = LogSeverity.INFO
severity isa LogSeverity.T  # true
```
"""
module LogSeverity
    const T = String
    const DEBUG = "debug"
    const INFO = "info"
    const WARNING = "warning"
    const ERROR = "error"
end
