-- UIKit: gemeinsames Aussehen + kleine Bauhelfer für alle Oberflächen
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local UI = {}

UI.Theme = {
	bg = Color3.fromRGB(16, 22, 30),
	panel = Color3.fromRGB(24, 33, 44),
	panel2 = Color3.fromRGB(33, 45, 58),
	stroke = Color3.fromRGB(70, 95, 110),
	text = Color3.fromRGB(236, 242, 244),
	dim = Color3.fromRGB(150, 168, 178),
	accent = Color3.fromRGB(88, 214, 170),
	gold = Color3.fromRGB(255, 205, 90),
	danger = Color3.fromRGB(255, 90, 80),
	warn = Color3.fromRGB(255, 170, 60),
	good = Color3.fromRGB(110, 230, 120),
	premium = Color3.fromRGB(190, 140, 255),
}
UI.Font = Enum.Font.GothamBold
UI.FontMed = Enum.Font.GothamMedium
UI.FontReg = Enum.Font.Gotham

function UI.IsTouch()
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

function UI.new(class, props, children)
	local inst = Instance.new(class)
	for k, v in pairs(props or {}) do
		if k ~= "Parent" then inst[k] = v end
	end
	for _, c in ipairs(children or {}) do c.Parent = inst end
	if props and props.Parent then inst.Parent = props.Parent end
	return inst
end

function UI.corner(r) return UI.new("UICorner", { CornerRadius = UDim.new(0, r or 10) }) end
function UI.stroke(color, th, tr) return UI.new("UIStroke", { Color = color or UI.Theme.stroke, Thickness = th or 1.5, Transparency = tr or 0.2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }) end
function UI.pad(p) return UI.new("UIPadding", { PaddingTop = UDim.new(0, p), PaddingBottom = UDim.new(0, p), PaddingLeft = UDim.new(0, p), PaddingRight = UDim.new(0, p) }) end
function UI.list(dir, gap, align)
	return UI.new("UIListLayout", { FillDirection = dir or Enum.FillDirection.Vertical, Padding = UDim.new(0, gap or 6), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = align or Enum.HorizontalAlignment.Left })
end

function UI.panel(props)
	props = props or {}
	local f = UI.new("Frame", {
		BackgroundColor3 = props.color or UI.Theme.panel,
		BackgroundTransparency = props.transparency or 0.08,
		Size = props.Size or UDim2.fromOffset(200, 100),
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		Name = props.Name or "Panel",
		BorderSizePixel = 0,
		LayoutOrder = props.LayoutOrder or 0,
		Visible = props.Visible ~= false,
		ZIndex = props.ZIndex or 1,
		Parent = props.Parent,
	}, { UI.corner(props.radius or 12), UI.stroke(props.strokeColor, props.strokeThickness) })
	return f
end

function UI.label(text, props)
	props = props or {}
	return UI.new("TextLabel", {
		Text = text or "",
		Font = props.Font or UI.FontMed,
		TextSize = props.TextSize or 16,
		TextColor3 = props.color or UI.Theme.text,
		BackgroundTransparency = 1,
		Size = props.Size or UDim2.new(1, 0, 0, (props.TextSize or 16) + 6),
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		TextXAlignment = props.align or Enum.TextXAlignment.Left,
		TextYAlignment = props.valign or Enum.TextYAlignment.Center,
		TextWrapped = props.wrap or false,
		RichText = props.rich or false,
		TextScaled = props.scaled or false,
		TextStrokeTransparency = props.strokeT or 1,
		LayoutOrder = props.LayoutOrder or 0,
		AutomaticSize = props.auto or Enum.AutomaticSize.None,
		ZIndex = props.ZIndex or 1,
		Name = props.Name or "Label",
		Parent = props.Parent,
	})
end

function UI.button(text, props, onClick)
	props = props or {}
	local b = UI.new("TextButton", {
		Text = text,
		Font = props.Font or UI.Font,
		TextSize = props.TextSize or 16,
		TextColor3 = props.textColor or UI.Theme.text,
		BackgroundColor3 = props.color or UI.Theme.panel2,
		AutoButtonColor = true,
		Size = props.Size or UDim2.fromOffset(140, 38),
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		LayoutOrder = props.LayoutOrder or 0,
		TextWrapped = true,
		Name = props.Name or "Button",
		ZIndex = props.ZIndex or 1,
		Parent = props.Parent,
	}, { UI.corner(props.radius or 9), UI.stroke(props.strokeColor or UI.Theme.stroke, 1.2, 0.35) })
	if onClick then b.Activated:Connect(onClick) end
	return b
end

function UI.tween(inst, t, props, style, dir)
	local tw = TweenService:Create(inst, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end

function UI.bar(parent, props)
	local bg = UI.new("Frame", { Size = props.Size, Position = props.Position or UDim2.new(), AnchorPoint = props.AnchorPoint or Vector2.zero, BackgroundColor3 = props.bg or Color3.fromRGB(20, 20, 24), BackgroundTransparency = props.bgT or 0.25, BorderSizePixel = 0, Name = props.Name or "Bar", Parent = parent, ZIndex = props.ZIndex or 1 }, { UI.corner(props.radius or 6) })
	local fill = UI.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = props.color or UI.Theme.good, BorderSizePixel = 0, Name = "Fill", Parent = bg, ZIndex = (props.ZIndex or 1) + 1 }, { UI.corner(props.radius or 6) })
	return bg, fill
end

return UI
