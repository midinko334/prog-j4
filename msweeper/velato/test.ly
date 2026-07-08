\version "2.24.3"
melody = \relative c' {
\clef treble
\key c \major
\time 4/4
\tempo 4 = 512

  c

  a g
  e f
  a dis
  g
  c

  a g
  e f
  d cis d
  g
  c

  a g
  e f
  d cis ais
  g
  c

  a g
  e f
  d cis ais
  g
  c

  a g
  e f
  d d d
  g
  c

  a g
  e f
  e dis
  g
  c

  a g
  e f
  ais a
  g
  c

  a g
  e f
  d d d
  g
  c

  a g
  e f
  d d f
  g
  c

  a g
  e f
  d cis ais
  g
  c

  a g
  e f
  d cis cis
  g
  c
}

\score {
\new Staff \melody
\midi { }
}
