--[[
____  ___ __   __
| __|/ _ \\ \ / /
| _|| (_) |> w <
|_|  \___//_/ \_\
FOX's Spring Lib v1.1.2
--]]
--#REGION ˚♡ Localize Vars ♡˚

local axis = vec(0, 1, 0)
local invertY = vec(1, -1, 1)

local mat4 = matrices.mat4()
local vec3 = vectors.vec3()

local _vec_rot = vectors.rotateAroundAxis
local _math_max = math.max
local _math_lerp = math.lerp

--#ENDREGION
--#REGION ˚♡ FOXSpring ♡˚

---@class FOXSpring
local FOXSpring = {}
local springMeta = { __index = FOXSpring, __type = "FOXSpring" }

---@package
function FOXSpring:tick()
	---@type FOXSpring.Internal
	local priv = self[1]

	local vel, userVel, pos = priv.vel, priv.userVel or 0, priv.pos
	local entity = self.entity or player

	-- Gets the directional velocity rotated to player-space
	
	local entityVelocity = self.velStrength and entity:getVelocity() * self.velStrength or 0
	local rawVelocity = (entityVelocity + userVel) * invertY

	local relativeVelocity = _vec_rot(entity:getBodyYaw(), rawVelocity, axis)
	local deformation = self.deformation or 0

	-- Do the physics (Hooke's Law)

	local displacement = pos - relativeVelocity - deformation
	local dampingForce = self.viscosity * vel
	local force = -self.springiness * displacement - dampingForce

	vel = (vel + force):clampLength(0, 100) -- Clamp velocity
	pos = pos + vel

	-- Shears the matrix according to directinal velocity, and clamp the flatness

	local mat = mat4:copy()
	mat.c2 = (pos + axis):augmented(0)
	mat.v22 = _math_max(0.05, mat.v22)

	-- Stretches the matrix inverse to the vertical shear

	local squish = mat.v22 ^ -self.squishiness
	mat:scale(squish, 1, squish)

	-- Apply offset matrix

	if self.offsetMat then mat:multiply(self.offsetMat) end

	-- Update private vars

	priv.vel = vel
	priv.userVel = nil
	priv.pos = pos
	priv.old = priv.new
	priv.new = mat
end

---@package
function FOXSpring:render(delta)
	---@type FOXSpring.Internal
	local priv = self[1]
	self.model:matrix(_math_lerp(priv.old, priv.new, delta))
end

---Removes this spring
function FOXSpring:remove()
	events.tick:remove(self[1].tick)
	events.render:remove(self[1].render)
end

---Applies a temporary directinal force to this spring
---@param force Vector3
function FOXSpring:applyForce(force)
	self[1].userVel = (self[1].userVel or 0) - force
end

--#ENDREGION
--#REGION ˚♡ FOXSpringLib ♡˚

---@class FOXSpringLib
local FOXSpringLib = setmetatable({}, { __type = "FOXSpringLib" })

---Creates a new spring
---@param model ModelPart|RenderTask.any|EntityTask
---@param cfg FOXSpring.Config?
---@return FOXSpring
function FOXSpringLib:new(model, cfg)
	-- Setup configs

	---@class FOXSpring.Config
	---@field model ModelPart|RenderTask.any|EntityTask? Model to apply springiness to
	---@field entity Player|LivingEntity? `nil` - The entity to take relative velocity from. If this is nil, it will default to the avatar entity
	---@field velStrength number|Vector3? `1, 1, 1` - How much the player's velocity affects the spring
	---@field offsetMat Matrix4? `nil` - Applies an offset matrix which you can scale, transform, and rotate
	---@field springiness number|Vector3? `1, 1, 1` - How much the force will try to spring back. Recommended values between 0 and 2
	---@field squishiness number? `0.5` - How much to widen the spring when it compresses
	---@field viscosity number? `0.5` - How easy it is for the spring to stay springy. Recommended values between 0 and 1
	---@field deformation Vector3? `0, 0, 0` - Deforms the spring in a direction relative to the spring's position in the world

	---@class FOXSpring
	---@field model ModelPart|RenderTask.any|EntityTask Model to apply springiness to
	---@field entity Player|LivingEntity? `nil` - The entity to take relative velocity from. If this is nil, it will default to the avatar entity
	---@field velStrength number|Vector3? `1, 1, 1` - How much the player's velocity affects the spring. If this is nil, the velocity won't be taken
	---@field offsetMat Matrix4 `nil` - Applies an offset matrix which you can scale, transform, and rotate
	---@field springiness number|Vector3 `1, 1, 1` - How much the force will try to spring back. Recommended values between 0 and 2
	---@field squishiness number `0.5` - How much to widen the spring when it compresses
	---@field viscosity number `0.5` - How easy it is for the spring to stay springy. Recommended values between 0 and 1
	---@field deformation Vector3 `0, 0, 0` - Deforms the spring in a direction relative to the spring's position in the world
	local spring = setmetatable({
		model = model,
		velStrength = vec(1, 1, 1),

		springiness = vec(1, 1, 1),
		squishiness = 0.5,
		viscosity = 0.5,
		deformation = vec(0, 0, 0),
	}, springMeta)

	for key, value in pairs(cfg or {}) do spring[key] = value end

	local t = type(spring.model)
	if not (t:find("Part") or t:find("Task")) then
		error("Invalid model given to this spring! Any model expected, got " .. t, 2)
	end

	-- Setup internals

	---@class FOXSpring.Internal
	---@field vel Vector3 The spring's velocity
	---@field userVel Vector3 The spring's user-applied velocity
	---@field pos Vector3 The spring's displacement
	---@field old Matrix4 Used for lerping in render, the old spring displacement
	---@field new Matrix4 Used for lerping in render, the new spring displacement
	---@field tick function This spring's tick function so it can be removed
	---@field render function This spring's render function so it can be removed
	---@package
	spring[1] = {
		vel = vec3:copy(),
		pos = vec3:copy(),
		old = mat4:copy(),
		new = mat4:copy(),

		tick = function() spring:tick() end,
		render = function(delta, context)
			if context == "PAPERDOLL" then return end
			spring:render(delta) 
		end,
	}

	events.tick = spring[1].tick
	events.render = spring[1].render

	return spring
end

--#ENDREGION

return FOXSpringLib
