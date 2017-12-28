-------------------------help------------------------------
local maxX = 20
local maxY = 20
local EdgeX = 3
local EdgeY = 3
local realMinX = -EdgeX + 1
local realMaxX = maxX + EdgeX
local realMinY = -EdgeY + 1
local realMaxY = maxY + EdgeY
local TitleRange = 9
local screenRect = {0, 0, display.width, display.height}
local MIN_X = 0
local MIN_Y = 0
local MAX_X = maxX
local MAX_Y = maxY
local titleWidth = 206
local titleHeight = 104
local titleCW = titleWidth/2
local titleCH = titleHeight/2

local MAX_LEN = 2000
local function CalPosId(iX,iY)
	iX = iX >= 0 and iX or MAX_LEN-iX
	iY = iY >= 0 and iY or MAX_LEN-iY
	return iX * 10000 + iY
end

local function CalPosXY(iPos)
	local iX,iY = math.floor(iPos / 10000), iPos % 10000
	iX = iX > MAX_LEN and MAX_LEN - iX or iX
	iY = iY > MAX_LEN and MAX_LEN - iY or iY
	return iX, iY
end

local function CalPosByXY(iX,iY)
	local iRealMinX = realMinX
	local iRealMaxX = realMaxX
	local iRealMinY = realMinY
	local iRealMaxY = realMaxY
	local cw = titleCW
	local ch = titleCH
	local x = cw * (iX - iRealMinX + iRealMaxY - iY + 1)
	local y = ch * (iRealMaxX - iX + iRealMaxY - iY + 1)
	return x, y
end

local function CalXYByPos(x, y, iScale)
	iScale = iScale or 1
	local iRealMinX = realMinX
	local iRealMaxX = realMaxX
	local iRealMinY = realMinY
	local iRealMaxY = realMaxY
	local cw = titleCW * iScale
	local ch = titleCH * iScale
	local iX = math.floor((x/cw - y/ch + iRealMinX + iRealMaxX)/2 + 0.5)
	local iY = math.floor((2*iRealMaxY + iRealMaxX - iRealMinX - x/cw - y/ch + 2)/2 + 0.5)
	return iX, iY
end

local function Set3DCamera(obj, time, angleDiff)
	time = time or 0
	angleDiff = angleDiff or 13
	local orbit = cc.OrbitCamera:create(time, 1, 0, 0, -angleDiff, 90, 0)
	orbit = cc.EaseSineOut:create(orbit)
	local seq = cc.Sequence:create({
		orbit
	})
	obj:runAction(seq)	
end

-------------------------help------------------------------

local MainScene = class("MainScene", cc.load("mvc").ViewBase)

function MainScene:onCreate()
    self:InitMap()
    self:AddTouch()
end

function MainScene:InitMap()
	self.m_Root = cc.Layer:create():addTo(self)
	self.m_TitleNode = cc.SpriteBatchNode:create("title.png"):addTo(self.m_Root, 1)
	self.m_BorderNode = cc.SpriteBatchNode:create("border.png"):addTo(self.m_Root, 2)

	local w = titleWidth
	local h = titleHeight
	local cw = titleCW
	local ch = titleCH
	local tw = (realMaxX - realMinX) * w + w
	local th = (realMaxY - realMinY) * h + h
	self.m_Root:setContentSize(cc.size(tw, th))

	self.m_TitlePool = {}
	self.m_BorderPool = {}

	-- initPos
	self:OnMove(0, -th/2)
	self:MoveTitle()
end

function MainScene:AddTouch()
	local layer = cc.LayerColor:create(cc.c4b(255, 255, 255, 0))
	layer:addTo(self)
	layer:setTouchEnabled(true)
    local onTouch = function (eventType, x, y, id)
        if eventType == "began"  then
			self.m_BeganX, self.m_BeganY = x, y
            return true
        elseif eventType == "moved" then 
			local dx = x - self.m_BeganX
			local dy = y - self.m_BeganY
			self.m_BeganX, self.m_BeganY = x, y
			local sx, sy = self.m_Root:getPosition()
			self:OnMove(sx + dx, sy + dy)
            return true
        elseif eventType == "ended" then 
            return true
        elseif eventType == "cancelled" then 
            return true
        end
    end
    layer:registerScriptTouchHandler(onTouch, false, 0, false)

    self.m_Layer = layer
end

function MainScene:GetScale()
	return self.m_Root:getScale()
end

function MainScene:GetRangeScale()
	return math.ceil(TitleRange/self:GetScale())
end

function MainScene:InitSmallArena()
	local scale   = self:GetScale()
    local anchor  = self.m_Root:getAnchorPoint()
	local offNum  = 2
    local offset  = {x = titleWidth * scale, y = titleHeight * scale}
	local size    = self.m_Root:getContentSize()
	local sw      = display.width
	local sh      = display.height
	local bw      = size.width*scale
	local bh      = size.height*scale
	bw            = bw + offNum * offset.x
	bh            = bh + offNum * offset.y
    self.m_Left   = cc.p(bw/bh * sh/2, bh/2 - sh/2)
    self.m_Top    = cc.p(bw/2 - sw/2, bh - bh/bw * (sw/2) - sh)
    self.m_Right  = cc.p(bw - sw - bw/bh * sh/2, bh/2 - sh/2)
    self.m_Bottom = cc.p(bw/2 - sw/2, bh/bw * (sw/2))
	self.m_OrgPos = cc.p((bw - 2 * offset.x) * anchor.x,
                        (bh - 2 * offset.y) * anchor.y)
	self.m_Offset = offset
end

function MainScene:CheckBound(x, y)
	local maxX, maxY, rw, rh = unpack(screenRect)
	local scale = self:GetScale()
	local size  = self.m_Root:getContentSize()
	local minX  = maxX + rw - size.width * scale
	local minY  = maxY + rh - size.height * scale

	x = math.max(x, minX)
	x = math.min(x, maxX)
	y = math.max(y, minY)
	y = math.min(y, maxX)

	return x, y
end

function MainScene:CheckInner(mapx, mapy)
	do return self:CheckBound(mapx, mapy) end

	self:InitSmallArena()
	local pos    = cc.p(self:CheckBound(mapx, mapy))
    local offset = self.m_Offset 
    local left   = self.m_Left
    local top    = self.m_Top
    local right  = self.m_Right
    local bottom = self.m_Bottom
    local orgPos = self.m_OrgPos 

    pos = cc.pSub(pos, offset)
    pos = cc.pSub(orgPos, pos)

    if pos.x < left.x or pos.x > right.x then
        pos.x = math.max(left.x, pos.x)
        pos.x = math.min(right.x, pos.x)
    end
    if pos.y < bottom.y or pos.y > top.y then
        pos.y = math.max(bottom.y, pos.y)
        pos.y = math.min(top.y, pos.y)
    end

    local midPos   = cc.pMidpoint(left, right)
    local result   = cc.pSub(pos, midPos)
    local dotX     = result.x > 0 and right or left
    local dotY     = result.y > 0 and top or bottom

    local areaSmall = math.abs(pos.x - midPos.x) * math.abs(pos.y - midPos.y)
    local areaBig   = math.abs(pos.x - dotX.x) * math.abs(pos.y - dotY.y)
    if areaSmall > areaBig then
        pos.y = (dotY.y - dotX.y)/(dotY.x - dotX.x) * (pos.x - dotY.x) + dotY.y
    end

    pos = cc.pSub(orgPos, pos)
    pos = cc.pAdd(offset, pos)

    return pos.x, pos.y
end

function MainScene:OnMove(x, y)
	x, y = self:CheckInner(x, y)
	self.m_Root:setPosition(x, y)
    self:MoveTitle()
end

function MainScene:GetViewPosRect()
	local rx, ry, rw, rh = unpack(screenRect)
	local lp1 = self.m_Root:convertToNodeSpace(cc.p(rx, ry))
	local x1, y1 = lp1.x, lp1.y
	local lp2 = self.m_Root:convertToNodeSpace(cc.p(rx+rw,ry+rh))
	local x2, y2 = lp2.x,lp2.y
	return x1, x2, y1, y2
end

function MainScene:GetViewTitle()
	local x1,x2,y1,y2 = self:GetViewPosRect()
	local xMid = (x1 + x2)/2
	local yMid = (y1 + y2)/2
	local iX_Mid, iY_Mid = CalXYByPos(xMid, yMid)
	local iScale = self:GetScale()
	if self.m_MX == iX_Mid and self.m_MY == iY_Mid then
		return
	end

	local viewTitles = {}
	local iRange = self:GetRangeScale()
	local iXS = iX_Mid - iRange
	local iXE = iX_Mid + iRange
	local iYS = iY_Mid - iRange
	local iYE = iY_Mid + iRange

	self.m_MX = iX_Mid
	self.m_MY = iY_Mid
	for iX = iXS, iXE do
		for iY = iYS, iYE do
			local iPos = CalPosId(iX, iY)
			viewTitles[iPos] = 1
		end
	end
	return viewTitles
end

function MainScene:MoveTitle()
	local viewTitles = self:GetViewTitle()
	if not viewTitles then
		return
	end

	self.m_ViewTitle = self.m_ViewTitle or {}

	-- add
	for iPos, _ in pairs(viewTitles) do
		if not self.m_ViewTitle[iPos] then
			local iX, iY = CalPosXY(iPos)
			local isBorder = iX < MIN_X or iX > MAX_X or iY < MIN_Y or iY > MAX_Y
			if isBorder then
				self:AddBorder(iPos)
			else
				self:AddTitle(iPos)
			end
		end
	end

	-- del
	for iPos, _ in pairs(self.m_ViewTitle) do
		if not viewTitles[iPos] then
			local iX, iY = CalPosXY(iPos)
			local isBorder = iX < MIN_X or iX > MAX_X or iY < MIN_Y or iY > MAX_Y
			if isBorder then
				self:DelBorder(iPos)
			else
				self:DelTitle(iPos)
			end
		end
	end

	self.m_ViewTitle = viewTitles
end

function MainScene:AddBorder(iPos)
	local iX, iY = CalPosXY(iPos)

    local title = display.newSprite("border.png")
    local x, y = CalPosByXY(iX, iY)
    title:setPosition(x, y)

	self.m_BorderPool[iPos] = title
	self.m_BorderNode:addChild(title)
end

function MainScene:AddTitle(iPos)
	local iX, iY = CalPosXY(iPos)

    local title = display.newSprite("title.png")
    local x, y = CalPosByXY(iX, iY)
    title:setPosition(x, y)

	self.m_TitlePool[iPos] = title
	self.m_TitleNode:addChild(title)
end

function MainScene:DelTitle(iPos)
	self.m_TitlePool[iPos]:removeFromParent(true)
	self.m_TitlePool[iPos] = nil
end

function MainScene:DelBorder(iPos)
	self.m_BorderPool[iPos]:removeFromParent(true)
	self.m_BorderNode[iPos] = nil
end

return MainScene
