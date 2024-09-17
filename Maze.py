from random import randint

class Maze:
    """
        Using a `2d list` to represent the maze, every number means a block,  
        which the first bit of the number mean the block can up (1),  
        the 2 mean can down (2),  
        the 3 mean can left (4),  
        the 4 mean can right (8),  
        and the 5 mean is visited (using for DFS to generate the maze) (16).  
    """

    def __init__(self, height, width):
        if height <= 0 | width <= 0:
            raise ValueError("size can't be 0 or negative")
        self.height = height
        self.width = width
        # Init the maze, filling with 0
        self.maze = [[0 for col in range(width)] for row in range(height)]
    
    def generateMaze(self):
        """
            Using DFS to generate the maze
        """
        maze = self.maze
        # save the coordinate of block
        xStack:list[int] = []
        yStack:list[int] = []
        
        # start on (0, 0)
        xStack.append(0)
        yStack.append(0)

        # is not empty
        while(xStack):
            x = xStack[-1] # get the last
            y = yStack[-1]
            # mark visited
            maze[y][x] |= 16

            # get next block
            jumpableBlocks:list[tuple[int, int]] = self.canJumpBlocks(x, y)

            # no more block can jump, jump back
            if not jumpableBlocks: # is empty
                xStack.pop()
                yStack.pop()
                continue

            tarX, tarY = jumpableBlocks[randint(0, len(jumpableBlocks)-1)]
            # save
            xStack.append(tarX)
            yStack.append(tarY)

            # update state
            self.update(x, y, tarX, tarY)

        return self.maze
        
    def update(self, x, y, tarX, tarY):
        deltaX = tarX - x # 0 1 -1
        deltaY = tarY - y # 0 1 -1
        updates = [None, (x, y, tarX, tarY), (tarX, tarY, x, y)]

        if deltaX:
            x1, y1, x2, y2 = updates[deltaX]
            self.maze[y1][x1] |= 8
            self.maze[y2][x2] |= 4
        elif deltaY:
            x1, y1, x2, y2 = updates[-deltaY]
            self.maze[y1][x1] |= 1
            self.maze[y2][x2] |= 2
            

    def isOut(self, x:int, y:int) -> bool:
        return (x < 0) | (x >= self.width) | (y < 0) | (y >= self.height)

    def canJump(self, x:int, y:int) -> bool:
        if self.isOut(x, y):
            return False
        return not (self.maze[y][x] & 16) # not out and not visited

    def canJumpBlocks(self, x:int, y:int) -> list[tuple[int, int]]:
        jumpableBlock = []
        if self.canJump(x, y-1):
            jumpableBlock.append((x, y-1))
        if self.canJump(x, y+1): 
            jumpableBlock.append((x, y+1))
        if self.canJump(x-1, y):
            jumpableBlock.append((x-1, y))
        if self.canJump(x+1, y):
            jumpableBlock.append((x+1, y))
        return jumpableBlock
    
    def writeMaze(self):
        for row in self.maze:
            for block in row:
                print("- -" if block & 1 else "---", end="")
            print("")
            for block in row:
                print(" " if block & 4 else "|", end="")
                print(" ", end="")
                print(" " if block & 8 else "|", end="")
            print("")
            for block in row:
                print("- -" if block & 2 else "---", end="")
            print("")

m = Maze(7, 20)
m.generateMaze()
m.writeMaze()