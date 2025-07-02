assert(Drawing, "Your exploit can't draw anything.")

local inf = math.huge
local abs = math.abs
local CFN = CFrame.new
local V3N = Vector3.new
local V2N = Vector2.new
local Draw = Drawing.new
local INT = false

local WHITE = Color3.new(1,1,1)
local V2Z = Vector2.zero

local User = game:GetService("Players").LocalPlayer
local Mouse = User:GetMouse()
local Resolution = V2N(Mouse.ViewSizeX,Mouse.ViewSizeY)
local Camera = workspace.CurrentCamera

local WTVP = Camera.WorldToViewportPoint
local WorldToViewport = function(...) return WTVP(Camera, ...) end

-- http://lua-users.org/wiki/CopyTable

function deepCopy(orig)
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
		lookup = function()
			local A = {}

			for Player, _ in pairs(Players) do
				A[Player] = Player.Character
			end

			return A
		end,

		dynamic = false,
	};
};

local conf = deepCopy(confT)

local function getBoundingBox(model: Instance, recursive: boolean, orientation: CFrame, mustcollide: boolean) ----- copypasted code xdflol
	if typeof(model) == "Instance" then
		model = recursive and model:GetDescendants() or model:GetChildren() --- had to modify some shit, last two variables are implemented by me
	end
	local orientation = orientation~=nil and orientation or CFN()
	local minx, miny, minz = inf,inf,inf
	local maxx, maxy, maxz = -inf,-inf,-inf
	for _, obj in pairs(model) do
		if obj:IsA("BasePart") then
			if (mustcollide==true and obj.CanCollide==false) then continue end
			local cf = orientation:toObjectSpace(obj.CFrame)
			local sx, sy, sz = obj.Size.X, obj.Size.Y, obj.Size.Z
			local x, y, z, R00, R01, R02, R10, R11, R12, R20, R21, R22 = cf:components()
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
	local wCf = orientation - orientation.p + orientation:pointToWorldSpace(omiddle)
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
		Box = Draw("Quad"),
	}
end



game:GetService('Players').PlayerAdded:Connect(registerPlayer)
for _, Player in pairs(game:GetService('Players'):GetPlayers()) do registerPlayer(Player) end
game:GetService('Players').PlayerRemoving:Connect(dropPlayer)



game:GetService('RunService').PreAnimation:Connect(function() -- Visuals loop
	Camera = workspace.CurrentCamera
	local FovDelta = (70/Camera.FieldOfView)

	for Player, Character in (conf.esp.lookup()) do
		local UR,UL,DL,DR,V1,V2,V3,V4
		local Box = Players[Player].Box
		local TeamColor = Player.TeamColor.Color:Lerp(WHITE,.5) or WHITE

		if Character then
			local Pos, Size = getBoundingBox(
				Character, 
				false, 
				conf.esp.dynamic and Character:GetModelCFrame() or CFN(Character:GetModelCFrame().p)*Camera.CFrame.Rotation, 
				true
			)

			local standard = (0.009*Resolution.Y*(Size.X+Size.Y)*FovDelta); standard = 2*standard/(Camera.CFrame.p-Pos.p).Magnitude

			UR,V1 = WorldToViewport(Pos*(V3N(Size.X,Size.Y,0)))
			UL,V2 = WorldToViewport(Pos*(V3N(-Size.X,Size.Y,0)))
			DL,V3 = WorldToViewport(Pos*(V3N(-Size.X,-Size.Y,0)))
			DR,V4 = WorldToViewport(Pos*(V3N(Size.X,-Size.Y,0)))

			Box.PointA = V2N(UR.X,UR.Y)
			Box.PointB = V2N(UL.X,UL.Y)
			Box.PointC = V2N(DL.X,DL.Y)
			Box.PointD = V2N(DR.X,DR.Y)
			
		else
			-- Solara moment
			Box.PointA = V2Z
			Box.PointB = V2Z
			Box.PointC = V2Z
			Box.PointD = V2Z
			--
		end

		Box.Visible = V1 and V2 and V3 and V4

		Box.Transparency = 1
		Box.Color = TeamColor
	end
end)

return conf, confT