import std/random
import std/sequtils

type
  CellContent* = enum
    ccSafe, ccMine

  CellMark* = enum
    cmNone, cmFlag, cmQuestion

  Cell* = object
    content*: CellContent
    mark*: CellMark
    opened*: bool
    adjacentMines*: int

  GameState* = enum
    gsPlaying, gsCleared, gsExploded

  Board* = object
    size*: int
    mineCount*: int
    cells*: seq[Cell]
    state*: GameState
    firstClickDone*: bool

func idx*(b: Board, x, y: int): int {.inline.} =
  y * b.size + x

func inBounds*(b: Board, x, y: int): bool {.inline.} =
  x >= 0 and x < b.size and y >= 0 and y < b.size

iterator neighbors*(b: Board, x, y: int): tuple[nx, ny: int] =
  for dy in -1 .. 1:
    for dx in -1 .. 1:
      if dx == 0 and dy == 0: continue
      let nx = x + dx
      let ny = y + dy
      if b.inBounds(nx, ny):
        yield (nx, ny)

proc newBoard*(size, mineCount: int): Board =
  result.size = size
  result.mineCount = mineCount
  result.cells = newSeq[Cell](size * size)
  for c in result.cells.mitems:
    c = Cell(content: ccSafe, mark: cmNone, opened: false, adjacentMines: 0)
  result.state = gsPlaying
  result.firstClickDone = false

proc placeMines*(b: var Board, safeX, safeY: int) =
  var forbidden: seq[int] = @[b.idx(safeX, safeY)]
  for (nx, ny) in b.neighbors(safeX, safeY):
    forbidden.add b.idx(nx, ny)

  var candidates = toSeq(0 ..< b.cells.len).filterIt(it notin forbidden)
  candidates.shuffle()

  for i in 0 ..< min(b.mineCount, candidates.len):
    b.cells[candidates[i]].content = ccMine

proc countAdjacentMines(b: Board, x, y: int): int =
  result = 0
  for (nx, ny) in b.neighbors(x, y):
    if b.cells[b.idx(nx, ny)].content == ccMine:
      inc result

proc openCell*(b: var Board, x, y: int) =
  if not b.inBounds(x, y): return
  let i = b.idx(x, y)
  if b.cells[i].opened: return
  if b.cells[i].mark != cmNone: return  ## マーク済みマスは誤操作防止のため開かない
  if b.cells[i].content == ccMine:
    b.cells[i].opened = true
    return

  b.cells[i].opened = true
  let count = b.countAdjacentMines(x, y)
  b.cells[i].adjacentMines = count

  if count == 0:
    for (nx, ny) in b.neighbors(x, y):
      let ni = b.idx(nx, ny)
      if not b.cells[ni].opened and b.cells[ni].content == ccSafe and b.cells[ni].mark == cmNone:
        b.openCell(nx, ny)

proc chordOpen*(b: var Board, x, y: int) =
  let i = b.idx(x, y)
  if not b.cells[i].opened: return
  let num = b.cells[i].adjacentMines
  if num == 0: return

  var flagCount = 0
  for (nx, ny) in b.neighbors(x, y):
    if b.cells[b.idx(nx, ny)].mark == cmFlag:
      inc flagCount

  if flagCount != num: return

  for (nx, ny) in b.neighbors(x, y):
    let ni = b.idx(nx, ny)
    if b.cells[ni].mark == cmFlag and b.cells[ni].content != ccMine:
      discard
    if b.cells[ni].mark == cmNone and not b.cells[ni].opened:
      b.openCell(nx, ny)

proc toggleMark*(b: var Board, x, y: int) =
  let i = b.idx(x, y)
  if b.cells[i].opened: return
  case b.cells[i].mark
  of cmNone: b.cells[i].mark = cmFlag
  of cmFlag: b.cells[i].mark = cmQuestion
  of cmQuestion: b.cells[i].mark = cmNone

proc checkClear*(b: Board): bool =
  for c in b.cells:
    if c.content == ccSafe and not c.opened:
      return false
  true

proc revealAllMines*(b: var Board) =
  for c in b.cells.mitems:
    if c.content == ccMine:
      c.opened = true
