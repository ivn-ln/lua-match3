Directions = {
    ["r"] = "right",
    ["l"] = "left",
    ["u"] = "up",
    ["d"] = "down",
}

JewelTypes = {
	empty = -1
}

-- Visuals for the base jewels, i.e. uncombined / not powered up
JewelsVisuals = {
	[-1] = { symbol = " ", color = "\27[37m" }, -- Empty
    [1] = { symbol = "A", color = "\27[31m" }, -- Red
    [2] = { symbol = "B", color = "\27[32m" }, -- Green
    [3] = { symbol = "C", color = "\27[33m" }, -- Yellow
    [4] = { symbol = "D", color = "\27[34m" }, -- Blue
    [5] = { symbol = "E", color = "\27[35m" }, -- Magenta
    [6] = { symbol = "F", color = "\27[36m" }, -- Cyan
}

-- Jewel class
Jewel = {}
Jewel.__index = Jewel

Jewel.destroyEffect = nil

function Jewel.new(type, x, y)
    local self = setmetatable({}, Jewel)
    self.type = type
    self.x = x
    self.y = y
    return self
end

function Jewel:destroy()
	if self.destroyEffect then
		self.destroyEffect:trigger(self)
	end
	self.type = -1
end

-- Base destroy effect class
DestroyEffect = {}
DestroyEffect.__index = DestroyEffect

function DestroyEffect.new()
	local self = setmetatable({}, DestroyEffect)
	return self
end

function DestroyEffect:trigger(jewel)
	io.stderr:write("Attempted using base destroy effect class, use a subclass")
end

-- Base match class
Match = {}
Match.__index = Match

function Match.new()
    local self = setmetatable({}, Match)
    return self
end

function Match.check(jewels)
    io.stderr:write("Attempted using base match class, use a subclass")
    return {}
end

-- Match 3 class
Match3 = setmetatable({}, { __index = Match })
Match3.__index = Match3

function Match3.new()
    local self = setmetatable({}, Match3)
    return self
end

function Match3.check(grid)
    local matchedJewels = {}

    -- Check for horizontal matches
    for i = 1, #grid do
        local row = grid[i]
        local currentType = row[1].type
        local matchStart = 1

        for j = 2, #row + 1 do
            if j <= #row and row[j].type == currentType then
                -- Continue the match
            else
                -- End of match
                local matchLength = j - matchStart
                if matchLength >= 3 then
                    -- Add all jewels in the match to the matchedJewels table
                    for k = matchStart, j - 1 do
                        table.insert(matchedJewels, row[k])
                    end
                end
                -- Start a new match
                if j <= #row then
                    currentType = row[j].type
                    matchStart = j
                end
            end
        end
    end

    -- Check for vertical matches
    for j = 1, #grid[1] do
        local currentType = grid[1][j].type
        local matchStart = 1

        for i = 2, #grid + 1 do
            if i <= #grid and grid[i][j].type == currentType then
                -- Continue the match
            else
                -- End of match
                local matchLength = i - matchStart
                if matchLength >= 3 then
                    -- Add all jewels in the match to the matchedJewels table
                    for k = matchStart, i - 1 do
                        table.insert(matchedJewels, grid[k][j])
                    end
                end
                -- Start a new match
                if i <= #grid then
                    currentType = grid[i][j].type
                    matchStart = i
                end
            end
        end
    end

    return matchedJewels
end

-- List of matches to check
Matches = {
    Match3
}

-- Board class
Board = {}
Board.__index = Board

function Board.new(rows, cols)
    local self = setmetatable({}, Board)
    self.rows = rows
    self.cols = cols
    self.grid = {}

    -- Initialize grid with empty jewels
	math.randomseed(os.time())
    for i = 1, rows do
        self.grid[i] = {}
        for j = 1, cols do
            self.grid[i][j] = Jewel.new(-1)
        end
    end

    return self
end

function Board:swap(row1, col1, row2, col2)
	local jewel1 = self.grid[row1][col1]
    local jewel2 = self.grid[row2][col2]
	jewel1.x, jewel1.y, jewel2.x, jewel2.y = jewel2.x, jewel2.y, jewel1.x, jewel1.y
    self.grid[row1][col1], self.grid[row2][col2] = jewel2, jewel1
end

function Board:checkMatches()
	local foundMatches = {}
    for _, match in ipairs(Matches) do
		local matches = match.check(self.grid)
		if #matches > 0 then
			for _, jewel in ipairs(matches) do
				if jewel.type == -1 then
					-- Skip the loop if the jewel has already been destroyed
					goto continue
				end
				table.insert(foundMatches, jewel)
				::continue::
			end
		end
    end

	-- Return true if any matches were found
	return foundMatches
end

-- Updates the board after jewels were removed
function Board:gravity()
    local rows = self.rows
    local cols = self.cols

    -- Repeat until no more empty jewels
    while #self:getJewelsOfType(-1) > 0 do
        for j = 1, cols do
            for i = 1, rows do
                if self.grid[i][j].type == -1 then

                    -- Move jewels to the bottom to fill the empty space
                    for k = j, 2, -1 do
                        self:swap(i, k, i, k - 1)
                    end

                    -- Spawn a new jewel on the top
                    self.grid[i][1].type = math.random(1, 6)
                end
            end
        end
    end
end

function Board:generate()
	--Fill the grid with random jewels
	math.randomseed(os.time())
    for i = 1, self.rows do
        for j = 1, self.cols do
            self.grid[i][j] = Jewel.new(math.random(1, 6))
        end
    end

    -- Ensure no initial matches
    while #self:checkMatches() > 0 do
        -- If matches exist, regenerate the board
        for i = 1, self.rows do
            for j = 1, self.cols do
                self.grid[i][j] = Jewel.new(math.random(1, 6))
            end
        end
    end
end

function Board:checkViableMoves()
	local viableMoves = false
    for i = 1, self.rows do
        for j = 1, self.cols do
            -- Check swap with the jewel to the right
            if j < self.cols then
                self:swap(i, j, i, j + 1)

                if self:checkMatches() then
                    self:swap(i, j, i, j + 1)
                    viableMoves = true
                    return viableMoves
                else
					-- Swap back
                    self:swap(i, j, i, j + 1)
                end
            end

            -- Check swap with the jewel below
            if i < self.rows then
                self:swap(i, j, i + 1, j)

                if self:checkMatches() then
                    self:swap(i, j, i + 1, j)
					viableMoves = true
                    return viableMoves
                else
					-- Swap back
                    self:swap(i, j, i + 1, j)
                end
            end
        end
    end

    return viableMoves
end

function Board:shuffle()
    -- Flatten the board into a 1D list
    local jewels = {}
    for i = 1, self.rows do
        for j = 1, self.cols do
            table.insert(jewels, self.grid[i][j])
        end
    end

    -- Shuffle the jewels
    for i = #jewels, 2, -1 do
        local j = math.random(i)
        jewels[i], jewels[j] = jewels[j], jewels[i]
    end

    -- Reconstruct the board from the shuffled list
    local index = 1
    for i = 1, self.rows do
        for j = 1, self.cols do
            self.grid[i][j] = jewels[index]
            index = index + 1
        end
    end
end

function Board:getJewelsOfType(type)
    local jewels = {}
    for i = 1, self.rows do
        for j = 1, self.cols do
            if self.grid[i][j].type == type then
                table.insert(jewels, self.grid[i][j])
            end
        end
    end
    return jewels
end

-- Input handler class, static
InputHandler = {}

InputHandler.commands = {
    ["m"] = function(x, y, direction)
        print("Moving (" .. x .. ", " .. y .. ") in direction: " .. direction)
        local new_x = direction == Directions.r and (x + 1) or (direction == Directions.l and x - 1 or x)
        local new_y = direction == Directions.d and (y + 1) or (direction == Directions.u and y - 1 or y)
        return GameInterface.move(x + 1, y + 1, new_x + 1, new_y + 1)
    end,
}

function InputHandler.handleInput(input)
    local success = false

    local parts = {}
    for part in input:gmatch("%S+") do
        table.insert(parts, part)
    end

    -- Check if input is valid
    if #parts ~= 4 then
        io.stderr:write("Invalid input format. Expected: <command> <x> <y> <direction>\n")
        return success
    end

    local commandAlias = parts[1]
    local x = tonumber(parts[2])
    local y = tonumber(parts[3])
    local directionAlias = parts[4]

    local command = InputHandler.commands[commandAlias]
    if not command then
        io.stderr:write("Unknown command: " .. commandAlias .. "\n")
        return success
    end

    if not x or not y or x < 0 or y < 0 then
        io.stderr:write("Invalid coordinates. Expected non-negative numbers\n")
        return success
    end

    local direction = Directions[directionAlias]
    if not direction then
        io.stderr:write("Unknown direction: " .. directionAlias .. "\n")
        return success
    end

    success = true
    return command(x, y, direction) and success
end

-- Renderer class, static
Renderer = {}

Renderer.renderFunctions = {
    [Board] = function (entity)
        Renderer.drawBoard(entity)
    end,
    [Jewel] = function (entity)
        Renderer.drawJewel(entity)
    end
}

function Renderer.drawJewel(jewel)
    local baseJewel = JewelsVisuals[jewel.type]
    if baseJewel then
        io.write(baseJewel.color .. baseJewel.symbol .. "\27[0m ") -- Reset color
	end
end

function Renderer.drawBoard(board)
    for i = 1, board.rows do
        -- Colummn numbers
        if i == 1 then
            io.write("  ")
            for j = 1, board.cols do
                io.write(j - 1 .. " ")
            end
            print()
        end
        -- Row numbers
        io.write(i - 1 .. " ")
        for j = 1, board.cols do
            Renderer.drawJewel(board.grid[j][i])
        end
        print()
    end
end

function Renderer.dump(entity)
    if entity == nil then
        io.stderr:write("Cannot render nil entity\n")
        return
    end

    local renderFunction = Renderer.renderFunctions[getmetatable(entity)]

    if renderFunction then
        renderFunction(entity)
    else
        io.stderr:write("Error: No render function for this entity\n")
    end
end

-- Game interface class, static
GameInterface = {}

GameInterface.currentBoard = nil

function GameInterface.move(row1, col1, row2, col2)
    local success = false

    local board = GameInterface.currentBoard
    local checkUpperBounds = row1 <= board.rows and col1 <= board.cols and row2 <= board.rows and col2 <= board.cols
    local checkLowerBounds = row1 >= 1 and col1 >= 1 and row2 >= 1 and col2 >= 1
    if not (checkUpperBounds and checkLowerBounds) then
        io.stderr:write("Invalid move coordinates\n")
        return success
    end
    local jewel1 = board.grid[row1][col1]
    local jewel2 = board.grid[row2][col2]
	-- Check if any matches appeared
	if jewel1.type == -1 or jewel2.type == -1 then
		io.stderr:write("Cannot move empty jewel\n")
		return success
	end

	board:swap(row1, col1, row2, col2)

	if #board:checkMatches() < 1 then
		Renderer.dump(board)
		io.stderr:write("No matches appeared\n")
		-- Reverse the movement
		board:swap(row1, col1, row2, col2)
		Renderer.dump(board)
		return success
	end

    success = true
    return success
end

function GameInterface.tick()
    local board = GameInterface.currentBoard

	-- Renderer the board
    Renderer.dump(board)

	-- Check for matches
	local matches = board:checkMatches()
	for _, jewel in pairs(matches) do
		jewel:destroy()
	end

	-- Rererender the board with destoyed jewels
	print("Destroying matched jewels...")
	Renderer.dump(board)

	print("Filling empty slots...")
	board:gravity()
	Renderer.dump(board)
	while #board:checkMatches() > 0 do
		print("Checking")
		matches = board:checkMatches()
		for _, jewel in pairs(matches) do
			jewel:destroy()
		end
		print("Destroying matched jewels...")
		Renderer.dump(board)
		print("Filling empty slots...")
		board:gravity()
		Renderer.dump(board)
	end


	-- Check for empty jewels
	while not board:checkViableMoves() do
		board:shuffle()
	end
end

function GameInterface.gameLoop()
	-- Handle input until it succeeds
	print("Make your move")
	while not InputHandler.handleInput(io.read()) do
		io.stderr:write("Error handling input. Try again")
		print("Make your move")
		InputHandler.handleInput(io.read())
	end

	GameInterface.tick()

	GameInterface.gameLoop()
end

function GameInterface.init()
	-- Initialize the board
	local rows, cols = 10, 10
	local board = Board.new(rows, cols)
	GameInterface.currentBoard = board
	board:generate()

	-- Render the board
	Renderer.dump(GameInterface.currentBoard)

	-- Start the gameplay loop
	GameInterface.gameLoop()
end

GameInterface.init()
