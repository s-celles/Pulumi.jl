"""
Resource lifecycle states.

Per constitution's Enum Convention: module-scoped with type T and SCREAMING_SNAKE_CASE values.

# Usage
```julia
state = ResourceState.CREATING
state isa ResourceState.T  # true
```
"""
module ResourceState
    @enum T begin
        PENDING      # Not yet registered
        CREATING     # Registration in progress
        CREATED      # Successfully registered
        UPDATING     # Update in progress
        DELETING     # Deletion in progress
        DELETED      # Successfully deleted
        FAILED       # Operation failed
    end
end
