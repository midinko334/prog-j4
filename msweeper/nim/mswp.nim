import std/strutils
import std/times
import nigui
import board

const
  CELLPXMAX = 32
  CELLPXMIN = 12
  WINDOWPXMAX = 800
  BOARDSIZEMAX = 40
  NumberColors = [
    rgb(0, 0, 0),        # 0
    rgb(0, 0, 192),      # 1
    rgb(0, 127, 127),    # 2
    rgb(0, 192, 0),      # 3
    rgb(127, 127, 0),    # 4
    rgb(192, 0, 0),      # 5
    rgb(255, 0, 255),    # 6
    rgb(0, 0, 0),        # 7
    rgb(127, 127, 127),  # 8
  ]

type
  App_status=object
    board: board
    cellpx: int
    startime: float
    endtime: float

proc XY(size: int): int = size*size

func getcellpx(size: int): int =
  result = WINDOWPXMAX div size
  result = max(result, CELLPXMIN)
  result = min(result, CELLPXMAX)

proc game_start(): tuple[size, mine: int] =
  var size=0
  var mine=0

  echo "=== M Sweeper ==="

  while size < 2 or size > BOARDSIZEMAX:
    stdout.write "Board size (Max " & $BOARDSIZEMAX & " Min 2): "
    try:
      size = parseInt(readLine(stdin))
      if size < 2 or size > BOARDSIZEMAX:
        echo "Invalid Input"
    except ValueError:
      echo "Invalid Input"
 
  while mine >= XY(size) or mine <= 0:
    stdout.write "Mine count : "
    try:
      mine = parseInt(readLine(stdin))
      if mine >= XY(size) or mine <= 0:
        echo "Invalid Input"
    except ValueError:
      echo "Invalid Input"
 
  result = (size, mine)

proc title_print(window: Window, game_status: App_status) =
  case game_status.board.state
  of gs_playing:
    window.title = "Msweeper"
  of gs_exploded:
    window.title = "*** GAME OVER ***"
  of gs_cleared:
    window.title = "*** GAME CLEAR ***"

proc board_print(control: Control, game_status: App_status, restartflag: int) =
  let cellpx = game_status.cellpx
  let canvas = control.canvas
  let game = game_status.board
 
  canvas.areaColor = rgb(245, 245, 245)
  canvas.drawRectArea(0, 0, control.width, control.height)
 
  for y in 0 ..< game.size:
    for x in 0 ..< game.size:
      let cell = game.cells[game.idx(x, y)]
      let rx = x * cellpx
      let ry = y * cellpx
 
      if cell.opened:
        canvas.areaColor =
          if game_status.board.state == gs_exploded:
            if cell.content == ccmine and cell.mark != cmmark: rgb(255, 95, 95)
            elif cell.content == ccsafe and cell.mark == cmmark: rgb(255, 95, 95)
            else: rgb(222, 222, 222)
          else: rgb(222, 222, 222)
      else:
        canvas.areaColor = rgb(191, 191, 191)
 
      canvas.drawRectArea(rx, ry, cellpx, cellpx)
      canvas.lineColor = rgb(127, 127, 127)
      canvas.drawRectOutline(rx, ry, cellpx, cellpx)
 
      canvas.fontSize = 14
 
      if cell.opened and cell.mark == cmmark:
        if cell.content == ccsafe:
          canvas.textColor = rgb(0, 0, 0)
        else:
          canvas.textColor = rgb(255, 127, 0)
        canvas.drawTextCentered("M", rx, ry, cellpx, cellpx)
      elif cell.opened and cell.content == ccmine:
        canvas.textColor = rgb(0, 0, 0)
        canvas.drawTextCentered("*", rx, ry, cellpx, cellpx)
      elif cell.opened and cell.near_mines > 0:
        canvas.textColor = NumberColors[cell.near_mines]
        canvas.drawTextCentered($cell.near_mines, rx, ry, cellpx, cellpx)
      elif not cell.opened:
        case cell.mark
        of cmmark:
          canvas.textColor = rgb(255, 127, 0)
          canvas.drawTextCentered("M", rx, ry, cellpx, cellpx)
        of cmQ:
          canvas.textColor = rgb(255, 127, 127)
          canvas.drawTextCentered("?", rx, ry, cellpx, cellpx)
        of cmN:
          discard

  canvas.areaColor = rgb(191, 191, 191)
 
  canvas.drawRectArea(0, (game.size+1)*cellpx, cellpx*4, cellpx)
  canvas.lineColor = rgb(127, 127, 127)
  canvas.drawRectOutline(0, (game.size+1)*cellpx, cellpx*4, cellpx)
  canvas.fontSize = 20
  
  if game_status.board.state != gsPlaying:
    canvas.textColor = rgb(0, 0, 0)
    let time = game_status.endtime - game_status.startime
    let timestr = formatFloat(time, ffDecimal, 1)
    canvas.drawTextCentered($timestr & "s", 6*cellpx, (game.size+1)*cellpx, cellpx, cellpx)
    canvas.textColor = rgb(0, 0, 127)
    canvas.drawTextCentered("Restart", 0, (game.size+1)*cellpx, cellpx*4, cellpx)    
  elif restartflag==1:
    canvas.textColor = rgb(255, 0, 0)
    canvas.drawTextCentered("Are You Sure?", 0, (game.size+1)*cellpx, cellpx*4, cellpx)
  else:
    canvas.textColor = rgb(0, 127, 0)
    canvas.drawTextCentered("Restart", 0, (game.size+1)*cellpx, cellpx*4, cellpx)

proc input_click(control: Control, window: Window, event: MouseEvent, game_status: var App_status, restartflag: var int) =
  let cellpx = game_status.cellpx
  let x = event.x div cellpx
  let y = event.y div cellpx
  let game = game_status.board
 
  if event.button == MouseButton_Left and x in 0..3 and y == game.size + 1:
    if restartflag == 1:
      game_status.board = new_board(game.size, game.mine_count)
      restartflag = 0
    else:
      restartflag = 1
    control.forceRedraw()
    title_print(window, game_status)
    return

  if game_status.board.state != gsPlaying:
    restartflag = 1
    return
  if not game_status.board.inBounds(x, y):
    restartflag = 0
    return

  let i = game_status.board.idx(x, y)

  restartflag=0
  if event.button == MouseButton_Right:
    game_status.board.toggle_mark(x, y)
  elif event.button == MouseButton_Left:
    if game_status.board.cells[i].opened:
      game_status.board.opencell_near(x, y)
    else:
      if not game_status.board.fc_done:
        game_status.board.setup(x, y)
        game_status.startime = epochTime()
        game_status.board.fc_done = true
      game_status.board.open_cell(x, y)
 
  if game_status.board.state == gs_exploded:
    game_status.board.fg_opencell()
    game_status.endtime = epochTime()
    restartflag=1
  elif game_status.board.check_clear():
    game_status.board.state = gs_cleared
    game_status.board.fg_opencell()
    game_status.endtime = epochTime()
    restartflag=1
 
  control.forceRedraw()
  title_print(window, game_status)


proc main() =
  var game_status: App_status
  var restartflag = 0

  let (size, mine) = game_start()
  game_status = App_status(board: new_board(size, mine), cellpx: getcellpx(size))
 
  app.init()
 
  var window = newWindow("Msweeper")
  window.width = game_status.board.size * game_status.cellpx + 16
  window.height = game_status.board.size * game_status.cellpx + 2 * game_status.cellpx + 40
 
  var board_control = new_control()
  board_control.width = game_status.board.size * game_status.cellpx
  board_control.height = game_status.board.size * game_status.cellpx + 2 * game_status.cellpx
 
  board_control.onDraw = proc(event: DrawEvent) =
    board_print(board_control, game_status, restartflag)
 
  board_control.onMouseButtonUp = proc(event: MouseEvent) =
    input_click(board_control, window, event, game_status, restartflag)
 
  window.add(board_control)
  window.show()
  app.run()
 
when isMainModule:
  main()
