import nigui
import board
 
const
  CellPx = 28
  BoardSizeDefault = 4
  MineCountDefault = 6
 
type
  AppState = object
    board: Board
 
var gameState = AppState(board: newBoard(BoardSizeDefault, MineCountDefault))
 
# color
const NumberColors = [
  rgb(0, 0, 0),        # 0
  rgb(0, 0, 255),      # 1
  rgb(0, 255, 0),      # 2
  rgb(255, 0, 0),      # 3
  rgb(0, 0, 127),      # 4
  rgb(127, 0, 0),      # 5
  rgb(0, 127, 127),    # 6
  rgb(0, 0, 0),        # 7
  rgb(127, 127, 127),  # 8
]
 
proc redrawBoard(control: Control) =
  let canvas = control.canvas
  let b = gameState.board
 
  canvas.areaColor = rgb(245, 245, 245)
  canvas.drawRectArea(0, 0, control.width, control.height)
 
  for y in 0 ..< b.size:
    for x in 0 ..< b.size:
      let cell = b.cells[b.idx(x, y)]
      let rx = x * CellPx
      let ry = y * CellPx
 
      if cell.opened:
        canvas.areaColor =
          if cell.content == ccMine: rgb(255, 90, 90)
          else: rgb(222, 222, 222)
      else:
        canvas.areaColor = rgb(170, 170, 170)
 
      canvas.drawRectArea(rx, ry, CellPx, CellPx)
      canvas.lineColor = rgb(110, 110, 110)
      canvas.drawRectOutline(rx, ry, CellPx, CellPx)
 
      canvas.fontSize = 14
 
      if cell.opened and cell.content == ccMine:
        canvas.textColor = rgb(0, 0, 0)
        canvas.drawTextCentered("*", rx, ry, CellPx, CellPx)
      elif cell.opened and cell.adjacentMines > 0:
        canvas.textColor = NumberColors[cell.adjacentMines]
        canvas.drawTextCentered($cell.adjacentMines, rx, ry, CellPx, CellPx)
      elif not cell.opened:
        case cell.mark
        of cmFlag:
          canvas.textColor = rgb(200, 0, 0)
          canvas.drawTextCentered("M", rx, ry, CellPx, CellPx)
        of cmQuestion:
          canvas.textColor = rgb(0, 0, 200)
          canvas.drawTextCentered("?", rx, ry, CellPx, CellPx)
        of cmNone:
          discard
 
proc updateTitle(window: Window) =
  case gameState.board.state
  of gsPlaying:
    window.title = "Nim Minesweeper"
  of gsExploded:
    window.title = "*** GAME OVER ***"
  of gsCleared:
    window.title = "*** GAME CLEAR ***"
 
proc handleClick(control: Control, window: Window, event: MouseEvent) =
  if gameState.board.state != gsPlaying:
    return
 
  let x = event.x div CellPx
  let y = event.y div CellPx
  if not gameState.board.inBounds(x, y):
    return
 
  let i = gameState.board.idx(x, y)
 
  if event.button == MouseButton_Right:
    gameState.board.toggleMark(x, y)
  elif event.button == MouseButton_Left:
    if gameState.board.cells[i].opened:
      gameState.board.chordOpen(x, y)
    else:
      if not gameState.board.firstClickDone:
        gameState.board.placeMines(x, y)
        gameState.board.firstClickDone = true
      gameState.board.openCell(x, y)
      if gameState.board.cells[i].content == ccMine:
        gameState.board.state = gsExploded
 
  if gameState.board.state == gsExploded:
    gameState.board.revealAllMines()
  elif gameState.board.checkClear():
    gameState.board.state = gsCleared
 
  control.forceRedraw()
  updateTitle(window)
 
proc main() =
  app.init()
 
  var window = newWindow("Nim Minesweeper")
  window.width = gameState.board.size * CellPx + 16
  window.height = gameState.board.size * CellPx + 40
 
  var boardControl = newControl()
  boardControl.width = gameState.board.size * CellPx
  boardControl.height = gameState.board.size * CellPx
 
  boardControl.onDraw = proc(event: DrawEvent) =
    redrawBoard(boardControl)
 
  boardControl.onMouseButtonDown = proc(event: MouseEvent) =
    handleClick(boardControl, window, event)
 
  window.add(boardControl)
  window.show()
  app.run()
 
when isMainModule:
  main()
