--!strict
-- Shared UI look: dark rounded "pill" HUD, warm cream management screens.

local Theme = {}

Theme.Colors = {
	Pill = Color3.fromRGB(26, 22, 30),
	PillText = Color3.fromRGB(255, 255, 255),
	Muted = Color3.fromRGB(170, 165, 180),
	Red = Color3.fromRGB(214, 40, 40),
	RedDark = Color3.fromRGB(150, 28, 30),
	Yellow = Color3.fromRGB(255, 196, 40),
	Green = Color3.fromRGB(46, 190, 90),
	GreenDark = Color3.fromRGB(28, 120, 60),
	Blue = Color3.fromRGB(40, 130, 230),
	Purple = Color3.fromRGB(140, 80, 220),
	Cream = Color3.fromRGB(250, 244, 232),
	Paper = Color3.fromRGB(255, 252, 246),
	Ink = Color3.fromRGB(46, 30, 24),
	InkSoft = Color3.fromRGB(120, 100, 90),
	Line = Color3.fromRGB(232, 222, 206),
}

Theme.Font = Enum.Font.GothamBold
Theme.FontBlack = Enum.Font.GothamBlack
Theme.FontFun = Enum.Font.FredokaOne

function Theme.make(class: string, props: { [string]: any }, children: { Instance }?): any
	local inst = Instance.new(class :: any)
	for k, v in props do
		if k ~= "Parent" then
			(inst :: any)[k] = v
		end
	end
	if children then
		for _, ch in children do
			ch.Parent = inst
		end
	end
	if props.Parent then
		inst.Parent = props.Parent
	end
	return inst
end

function Theme.corner(r: number?): UICorner
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r or 12)
	return c
end

function Theme.pad(p: number, side: number?): UIPadding
	local u = Instance.new("UIPadding")
	u.PaddingTop = UDim.new(0, p)
	u.PaddingBottom = UDim.new(0, p)
	u.PaddingLeft = UDim.new(0, side or p)
	u.PaddingRight = UDim.new(0, side or p)
	return u
end

function Theme.stroke(color: Color3, thickness: number?, transparency: number?): UIStroke
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness or 1
	s.Transparency = transparency or 0
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	return s
end

function Theme.list(dir: Enum.FillDirection?, padding: number?, align: Enum.HorizontalAlignment?): UIListLayout
	local l = Instance.new("UIListLayout")
	l.FillDirection = dir or Enum.FillDirection.Vertical
	l.Padding = UDim.new(0, padding or 6)
	l.SortOrder = Enum.SortOrder.LayoutOrder
	if align then
		l.HorizontalAlignment = align
	end
	return l
end

function Theme.text(props: { [string]: any }): TextLabel
	local t = Theme.make("TextLabel", {
		BackgroundTransparency = 1,
		Font = props.Font or Theme.Font,
		TextColor3 = props.TextColor3 or Theme.Colors.PillText,
		TextSize = props.TextSize or 16,
		TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Left,
		Text = props.Text or "",
	})
	for k, v in props do
		(t :: any)[k] = v
	end
	return t
end

function Theme.button(props: { [string]: any }, onClick: () -> ()): TextButton
	local b = Theme.make("TextButton", {
		AutoButtonColor = true,
		BackgroundColor3 = props.BackgroundColor3 or Theme.Colors.Green,
		Font = props.Font or Theme.FontBlack,
		TextColor3 = props.TextColor3 or Color3.new(1, 1, 1),
		TextSize = props.TextSize or 16,
		Text = props.Text or "",
	})
	for k, v in props do
		if k ~= "Radius" then
			(b :: any)[k] = v
		end
	end
	Theme.corner(props.Radius or 10).Parent = b
	b.Activated:Connect(onClick)
	return b
end

function Theme.money(n: number): string
	local s = string.format("%.2f", n)
	local int, dec = string.match(s, "^(%-?%d+)(%.%d+)$")
	int = int or s
	local formatted = string.reverse((string.gsub(string.reverse(int :: string), "(%d%d%d)", "%1,")))
	if string.sub(formatted, 1, 1) == "," then
		formatted = string.sub(formatted, 2)
	end
	if string.sub(formatted, 1, 2) == "-," then
		formatted = "-" .. string.sub(formatted, 3)
	end
	return "$" .. formatted .. (dec or "")
end

return Theme
