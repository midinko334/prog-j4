import std/random
import std/sequtils

type
  cell_content* = enum
    ccsafe, ccmine

  cell_mark* = enum
    cmN, cmmark, cmQ

  cell* = object
    content*: cell_content
    mark*: cell_mark
    opened*: bool
    adjacent_mines*: int

  gstatus* = enum
    gs_playing, gs_cleared, gs_exploded

  board* = object
    size*: int
    mine_count*: int
    cells*: seq[cell]
    state*: gstatus
    fc_done*: bool

func idx*(b: board, x, y: int): int {.inline.} =
  y * b.size + x

func in_bounds*(b: board, x, y: int): bool {.inline.} =
  x >= 0 and x < b.size and y >= 0 and y < b.size

iterator neighbors*(b: board, x, y: int): tuple[nx, ny: int] =
  for dy in -1 .. 1:
    for dx in -1 .. 1:
      if dx == 0 and dy == 0: continue
      let nx = x + dx
      let ny = y + dy
      if b.in_bounds(nx, ny):
        yield (nx, ny)

proc new_board*(size, mine_count: int): board =
  result.size = size
  result.mine_count = mine_count
  result.cells = newSeq[cell](size * size)
  for c in result.cells.mitems:
    c = cell(content: ccsafe, mark: cmN, opened: false, adjacent_mines: 0)
  result.state = gs_playing
  result.fc_done = false

proc place_mines*(b: var board, safe_x, safe_y: int) =
  var forbidden: seq[int] = @[b.idx(safe_x, safe_y)]
  for (nx, ny) in b.neighbors(safe_x, safe_y):
    forbidden.add b.idx(nx, ny)

  var candidates = toSeq(0 ..< b.cells.len).filterIt(it notin forbidden)
  candidates.shuffle()

  for i in 0 ..< min(b.mine_count, candidates.len):
    b.cells[candidates[i]].content = ccmine

proc count_adjacent_mines(b: board, x, y: int): int =
  result = 0
  for (nx, ny) in b.neighbors(x, y):
    if b.cells[b.idx(nx, ny)].content == ccmine:
      inc result

proc open_cell*(b: var board, x, y: int) =
  if not b.in_bounds(x, y): return
  let i = b.idx(x, y)
  if b.cells[i].opened: return
  if b.cells[i].mark == cmmark: return
  if b.cells[i].content == ccmine:
    b.cells[i].opened = true
    b.state = gs_exploded
    return

  b.cells[i].opened = true
  let count = b.count_adjacent_mines(x, y)
  b.cells[i].adjacent_mines = count

  if count == 0:
    for (nx, ny) in b.neighbors(x, y):
      let ni = b.idx(nx, ny)
      if not b.cells[ni].opened and b.cells[ni].content == ccsafe:
        b.open_cell(nx, ny)

proc opencell_near*(b: var board, x, y: int) =
  let i = b.idx(x, y)
  if not b.cells[i].opened: return
  let num = b.cells[i].adjacent_mines
  if num == 0: return

  var mark_count = 0
  for (nx, ny) in b.neighbors(x, y):
    if b.cells[b.idx(nx, ny)].mark == cmmark:
      inc mark_count

  if mark_count != num: return

  for (nx, ny) in b.neighbors(x, y):
    let ni = b.idx(nx, ny)
    if b.cells[ni].mark != cmmark and not b.cells[ni].opened:
      if b.cells[ni].content == ccmine:
        b.cells[ni].opened = true
        b.state = gs_exploded
      else:
        b.open_cell(nx, ny)

proc toggle_mark*(b: var board, x, y: int) =
  let i = b.idx(x, y)
  if b.cells[i].opened: return
  case b.cells[i].mark
  of cmN:
    b.cells[i].mark = cmmark
  of cmmark:
    b.cells[i].mark = cmQ
  of cmQ:
    b.cells[i].mark = cmN

proc check_clear*(b: board): bool =
  for c in b.cells:
    if c.content == ccsafe and not c.opened:
      return false
  true

proc fg_opencell*(b: var board) =
  for y in 0 ..< b.size:
    for x in 0 ..< b.size:
      let i = b.idx(x, y)
      if b.cells[i].content == ccsafe and not b.cells[i].opened:
        b.cells[i].adjacent_mines = b.count_adjacent_mines(x, y)
      b.cells[i].opened = true
