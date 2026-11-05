-- Modele cinematique "bicyclette" SIMPLIFIE d'une voiture pilotee au clavier.
-- Ce n'est PAS la physique du G-Cruzer : pas de glissement, pas de suspension,
-- pas de collisions (sauf mur optionnel). Sert a verifier la logique du pilote.
local Car = {}
Car.__index = Car

function Car.new(x, z, headingDeg, p)
    p = p or {}
    local c = setmetatable({}, Car)
    -- headingDeg = cap au sens atan2(dx, dz) ; Roblox : look = (-sin(yaw), -cos(yaw))
    local h = math.rad(headingDeg)
    c.x, c.z = x, z
    c.yaw = math.atan(-math.sin(h), -math.cos(h))
    c.v = 0; c.steer = 0; c.yawRate = 0
    c.accel = p.accel or 14; c.brakeDecel = p.brakeDecel or 25; c.revAccel = p.revAccel or 8
    c.revMax = p.revMax or 10; c.drag = p.drag or 2.5; c.vmax = p.vmax or 40
    c.steerRate = p.steerRate or 4; c.maxSteer = p.maxSteer or 0.6; c.wheelbase = p.wheelbase or 8
    c.wall = p.wall -- {x1,z1,x2,z2,...} : boite infranchissable
    return c
end
function Car:look() return -math.sin(self.yaw), -math.cos(self.yaw) end
function Car:step(dt, k)
    local target = (k.right and 1 or 0) - (k.left and 1 or 0)
    local ds = target - self.steer
    local m = self.steerRate * dt
    if ds > m then ds = m elseif ds < -m then ds = -m end
    self.steer = self.steer + ds
    if k.fwd and not k.back then
        if self.v < 0 then self.v = self.v + self.brakeDecel * dt else self.v = self.v + self.accel * dt end
        if self.v > self.vmax then self.v = self.vmax end
    elseif k.back and not k.fwd then
        if self.v > 0.5 then self.v = self.v - self.brakeDecel * dt
        else self.v = math.max(self.v - self.revAccel * dt, -self.revMax) end
    else
        local d = math.min(math.abs(self.v), self.drag * dt)
        self.v = self.v - (self.v > 0 and d or -d)
    end
    self.yawRate = -(self.v / self.wheelbase) * math.tan(self.steer * self.maxSteer)
    self.yaw = self.yaw + self.yawRate * dt
    local lx, lz = self:look()
    local nx, nz = self.x + lx * self.v * dt, self.z + lz * self.v * dt
    local w = self.wall
    if w and nx > w[1] and nx < w[3] and nz > w[2] and nz < w[4] then
        self.v = 0
    else
        self.x, self.z = nx, nz
    end
end
function Car:obs(t)
    local lx, lz = self:look()
    return { t = t, x = self.x, z = self.z, lx = lx, lz = lz, vx = lx * self.v, vz = lz * self.v, yaw = self.yawRate }
end
return Car
