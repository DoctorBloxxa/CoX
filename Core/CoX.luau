--!strict

assert(Drawing, "Your exploit can't draw anything.")

local inf = math.huge
local abs = math.abs
local clamp = math.clamp
local CFN = CFrame.new
local V3N = Vector3.new
local V2N = Vector2.new
local Draw = Drawing.new
local HSV = Color3.fromHSV
local INT = false

local WHITE = Color3.new(1,1,1)
local BLACK = Color3.new()
local LOWVAL = (2^30-1)
local V2Z = Vector2.zero

local User = game:GetService("Players").LocalPlayer
local Mouse = User:GetMouse()
local Resolution = V2N(Mouse.ViewSizeX,Mouse.ViewSizeY)
local Camera = workspace.CurrentCamera

local WTVP = Camera.WorldToViewportPoint
local WorldToViewport = function(...) return WTVP(Camera, ...) end

-- Define globals with strict types. Hopefully this helps shave off some frametime.

local method: (...any) -> {[Player]: Model}
local filter: (...any) -> boolean
local boundingbox: (any) -> boolean
local health: (...any) -> (number, Color3)

--


-- http://lua-users.org/wiki/CopyTable

function deepCopy(orig: any): any
	local orig_type = type(orig)
	local copy
	if orig_type == 'table' then
		copy = {}
		for orig_key, orig_value in next, orig, nil do
			copy[deepCopy(orig_key)] = deepCopy(orig_value)
		end
		setmetatable(copy, deepCopy(getmetatable(orig)))
	else -- number, string, boolean, etc
		copy = orig
	end
	return copy
end

local Players = {}

local confT = {
	esp = {
		dynamic = true,
		healthbar = false,

		lookup = function(): {[Player]: Model}
			local A = {}

			for Player, _ in pairs(Players) do
				A[Player] = Player.Character or game
			end

			return A
		end,
		
		boundingbox = function(Part: any): boolean
			return Part.ClassName == "Part" or Part.ClassName == "MeshPart"
		end,

		filter = function(Character: Model, Player: Player): boolean
			local focused = workspace:IsAncestorOf(Character) and not (Character:IsAncestorOf(Camera.CameraSubject) or Character == Camera.CameraSubject)

			local alive = true
			local Hum = Character:FindFirstChildOfClass("Humanoid")

			if Hum then
				alive = not (Hum.Health==0 or Hum.Health<0)
			end

			return focused and alive
		end,

		health = function(Character: Model, Player: Player): (number, Color3)
			local val = 1
			local Hum = Character:FindFirstChildOfClass("Humanoid")

			if Hum then
				val = (Hum.Health/Hum.MaxHealth)
			end

			return val, HSV(val*.4,.9,.98)
		end,
	};
};

local conf = deepCopy(confT)

local function getBoundingBox(model: Instance, recursive: boolean, orientation: CFrame, mustcollide: boolean) ----- copypasted code xdflol
	local modelt

	modelt = recursive and model:GetDescendants() or model:GetChildren() --- had to modify some shit, last two variables are implemented by me

	local minx, miny, minz = inf,inf,inf
	local maxx, maxy, maxz = -inf,-inf,-inf
	for _, obj in pairs(modelt) do
		if boundingbox(obj) then
			if (mustcollide==true and obj.CanCollide==false) then continue end
			local cf = orientation:ToObjectSpace(obj.CFrame)
			local sx, sy, sz = obj.Size.X, obj.Size.Y, obj.Size.Z
			local x, y, z, R00, R01, R02, R10, R11, R12, R20, R21, R22 = cf:GetComponents()
			local wsx = (abs(R00) * sx + abs(R01) * sy + abs(R02) * sz)*.5
			local wsy = (abs(R10) * sx + abs(R11) * sy + abs(R12) * sz)*.5
			local wsz = (abs(R20) * sx + abs(R21) * sy + abs(R22) * sz)*.5
			if minx > x - wsx then
				minx = x - wsx
			end
			if miny > y - wsy then
				miny = y - wsy
			end
			if minz > z - wsz then
				minz = z - wsz
			end
			if maxx < x + wsx then
				maxx = x + wsx
			end
			if maxy < y + wsy then
				maxy = y + wsy
			end
			if maxz < z + wsz then
				maxz = z + wsz
			end
		end
	end
	local omin, omax = V3N(minx, miny, minz), V3N(maxx, maxy, maxz)
	local omiddle = (omax+omin)*.5
	local wCf = orientation - orientation.Position + orientation:PointToWorldSpace(omiddle)
	local size = (omax-omin)
	return wCf, size
end

local function dropPlayer(Player: Player)
	if Players[Player] then
		for idx, val in pairs(Players[Player]) do
			val:Remove()
		end

		Players[Player] = nil
	end
end

local function registerPlayer(Player: Player)
	dropPlayer(Player)
	Players[Player] = {
		box = Draw("Quad"),
		healthBar = Draw("Line"),
		healthBarBackground = Draw("Line"),
	}

	Players[Player].box.ZIndex = LOWVAL+1
	Players[Player].healthBarBackground.ZIndex = LOWVAL+2
	Players[Player].healthBar.ZIndex = LOWVAL+3
end



game:GetService('Players').PlayerAdded:Connect(registerPlayer)
for _, Player in pairs(game:GetService('Players'):GetPlayers()) do registerPlayer(Player) end
game:GetService('Players').PlayerRemoving:Connect(dropPlayer)



local function renderLoop() -- Visuals loop
	Camera = workspace.CurrentCamera
	local FovDelta = (70/Camera.FieldOfView)

	for Player, Character in (method()) do
		local UR,UL,DL,DR,V1,V2,V3,V4
		local box = Players[Player].box
		local h1 = Players[Player].healthBarBackground
		local h2 = Players[Player].healthBar
		local teamColor = Player.TeamColor.Color:Lerp(WHITE,.5) or WHITE

		-- Solara moment. If Solara's drawing API wasn't this dogshit this could run much faster
		box.PointA = V2Z
		box.PointB = V2Z
		box.PointC = V2Z
		box.PointD = V2Z

		h1.From = V2Z
		h1.To = V2Z

		h2.From = V2Z
		h2.To = V2Z
		--

		if filter(Character, Player) then
			local CF = Character:GetPivot()

			if not conf.esp.dynamic then
				CF = CFN(CF.Position, Camera.CFrame.p)*CFrame.Angles(0,math.pi,0)
			end

			local Pos, Size = getBoundingBox(
				Character, 
				false, 
				CF, 
				false
			); Size*=.5

			--local standard = 1 + (((0.018*Resolution.Y*(Size.X+Size.Y)*FovDelta))/(Camera.CFrame.Position-Pos.Position).Magnitude)
			
			local standard = 1
			
			UR,V1 = WorldToViewport(Pos*(V3N(Size.X,Size.Y,0)))
			UL,V2 = WorldToViewport(Pos*(V3N(-Size.X,Size.Y,0)))
			DL,V3 = WorldToViewport(Pos*(V3N(-Size.X,-Size.Y,0)))
			DR,V4 = WorldToViewport(Pos*(V3N(Size.X,-Size.Y,0)))
			
			DL = V2N(DL.X,DL.Y)
			DR = V2N(DR.X,DR.Y)

			if conf.esp.healthbar then
				local h, c = health(Character, Player)

				h1.Color = BLACK
				h2.Color = BLACK

				h1.From = DL
				h1.To = DR

				h2.From = DL
				h2.To = DL + (DR-DL)*h
				h2.Color = c

				h1.Thickness = standard
				h2.Thickness = standard

				h1.Visible = V1 and V2 and V3 and V4
				h2.Visible = V1 and V2 and V3 and V4
			end

			if V1 and V2 and V3 and V4 then
				box.PointA = V2N(UR.X,UR.Y)
				box.PointB = V2N(UL.X,UL.Y)
				box.PointC = DL
				box.PointD = DR

				box.Thickness = standard
			end
		end

		box.Visible = V1 and V2 and V3 and V4
		box.Color = teamColor
	end
end

local tracker = {}
local configurator = {}

function configurator:enableESP()
	method = conf.esp.lookup
	filter = conf.esp.filter
	boundingbox = conf.esp.boundingbox
	health = conf.esp.health
	tracker.renderLoop = game:GetService("RunService").RenderStepped:connect(renderLoop)
end

function configurator:disableESP()
	tracker.renderLoop:Disconnect()

	for Player, Contents in Players do
		local box = Contents.box
		local h1 = Contents.healthBarBackground
		local h2 = Contents.healthBar

		box.PointA = V2Z
		box.PointB = V2Z
		box.PointC = V2Z
		box.PointD = V2Z

		h1.From = V2Z
		h1.To = V2Z

		h1.From = V2Z
		h2.To = V2Z

		box.Visible = false
		h1.Visible = false
		h2.Visible = false
	end
end

function configurator:setValue()
end

function configurator:getValue(): any
	return 1
end

return configurator