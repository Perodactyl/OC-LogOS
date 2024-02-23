---@meta
---@diagnostic disable: lowercase-global, duplicate-doc-alias

---@alias componentType componentType | "ocelot"
---@alias proxy proxy | OcelotProxy

---@class OcelotProxy : Proxy
--- @field type "ocelot"
---  @field getInstant             fun()                : integer Returns a high-resolution timer value (in nanoseconds).
---  @field getMaxCallBudget       fun()                : number  Returns the maximum call budget.
---  @field getRemainingCallBudget fun()                : number  Returns the remaining call budget.
---  @field getTimestamp           fun()                : integer Returns the current Unix timestamp (UTC, in milliseconds).
---  @field log                    fun(message: string)           Logs a message to the Ocelot console.