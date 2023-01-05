{ ascii turn-based game }

program BlueDrive;

uses CRT;

const
  { 0=floor, 1=wall, 2=door, 3=team1, 4=team2 }
  map1w = 15;
  map1h = 10;
  map1: array[0..(map1w*map1h-1)] of byte = (
    1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
    1,0,0,0,0,1,0,0,0,0,1,0,0,0,1,
    1,3,3,3,3,1,0,0,0,0,1,0,0,0,1,
    1,0,0,0,0,1,0,0,4,4,1,2,1,1,1,
    1,0,0,0,0,1,0,0,0,0,1,0,0,0,1,
    1,2,1,1,0,1,1,2,2,1,1,1,0,0,1,
    1,0,0,0,0,0,0,0,0,2,0,0,0,4,1,
    1,2,1,1,2,1,1,0,0,1,1,2,1,1,1,
    1,0,0,4,0,0,2,0,0,2,0,0,0,0,1,
    1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
  );

  maxHP = 3;
  playerTeam = 1;
  enemyTeam = 2;
  sidebarX = 51;
  sidebarY = 5;
  sidebarTopY = 1;

type
  actor = record
    x, y: integer;
    moved, fired: boolean;
    hp, team: byte;
  end;
  pactor = ^actor;
  emode = (mode_look, mode_move, mode_fire);
  tfmap = array[0..3999] of boolean;

var
  mapw, maph: integer;
  map: array[0..3999] of byte;
  FOVMap: array[0..3999] of boolean;
  actors: array[1..70] of actor;
  nactors: integer;
  cursorX, cursorY: integer;
  turn: integer;
  mode: emode;
  selected: integer;

procedure addActor(x, y: integer; team: byte);
begin
  nactors := nactors + 1;
  actors[nactors].x := x;
  actors[nactors].y := y;
  actors[nactors].team := team;
  actors[nactors].hp := maxHP;
  actors[nactors].moved := false;
  actors[nactors].fired := false;
end;

procedure loadMap(w, h: integer; m: array of byte);
var
  i: integer;
begin
  mapw := w;
  maph := h;
  cursorX := 0;
  cursorY := 0;
  nactors := 0;
  turn := 1;
  mode := mode_look;
  for i := 0 to w*h-1 do begin
    map[i] := m[i];
    if (m[i] = 3) or (m[i] = 4) then begin
      addActor(i mod w, i div w, m[i]-2);
      map[i] := 0;
    end;
  end;
end;

function sees(x1, y1, x2, y2: integer): boolean;
var
  x, y, xd, yd, d, i: integer;
begin
  xd := x2-x1;
  yd := y2-y1;
  if xd*xd+yd*yd > 10*10 then begin sees := false; exit; end;

  if xd < 0 then d := xd*-1 else d := xd;
  if yd > d then d := yd
  else if yd*-1 > d then d := yd*-1;

  if d = 0 then begin sees := true; exit; end;

  for i := 1 to d do begin
    x := x1 + (xd*i) div d;
    y := y1 + (yd*i) div d;
    if (x = x1) and (y = y1) then continue;
    if (x < 0) or (y < 0) or (x >= mapw) or (y >= maph) then begin
      sees := false;
      exit;
    end;
    if (x = x2) and (y = y2) then begin sees := true; exit; end;
    if map[y*mapw+x] <> 0 then begin sees := false; exit; end;
  end;
  sees := false;
end;

procedure getTeamFOV(t: byte);
var
  i, j: integer;
begin
  for i := 0 to mapw*maph-1 do
    FOVMap[i] := false;

  for i := 1 to nactors do
    if actors[i].team = t then
      for j := 0 to mapw*maph-1 do begin
        if FOVMap[j] then continue;
        FOVMap[j] := sees(actors[i].x, actors[i].y, j mod mapw, j div mapw);
      end;
end;

function actorAt(x, y: integer): integer;
var
  i: integer;
begin
  for i := 1 to nactors do
    if (actors[i].x = x) and (actors[i].y = y) then begin
      actorAt := i;
      exit;
    end;
  actorAt := 0;
end;

procedure getActorMov(a: pactor);
var
  i, xd, yd: integer;
begin
  for i := 0 to mapw*maph-1 do
    FOVMap[i] := false;

  for i := 0 to mapw*maph-1 do begin
    if map[i] = 1 then continue;
    if actorAt(i mod mapw, i div mapw) <> 0 then continue;
    xd := i mod mapw - a^.x;
    yd := i div mapw - a^.y;
    if xd*xd+yd*yd > 4*4 then continue;
    FOVMap[i] := sees(a^.x, a^.y, i mod mapw, i div mapw);
  end;
end;

procedure readyTeam(t: byte);
var
  i: integer;
begin
  for i := 1 to nactors do
    if actors[i].team = t then begin
      actors[i].moved := false;
      actors[i].fired := false;
    end;
end;

function shootActor(i: integer): boolean;
begin
  actors[i].hp := actors[i].hp - 1;
  if actors[i].hp > 0 then begin shootActor := false; exit; end;
  actors[i].hp := actors[nactors].hp;
  actors[i].x := actors[nactors].x;
  actors[i].y := actors[nactors].y;
  actors[i].moved := actors[nactors].moved;
  actors[i].fired := actors[nactors].fired;
  nactors := nactors-1;
  shootActor := true;
end;

function visibleEnemy(x, y: integer; t: byte): integer;
var
  i: integer;
begin
  for i := 1 to nactors do begin
    if actors[i].team = t then continue;
    if not sees(x, y, actors[i].x, actors[i].y) then continue;
    visibleEnemy := i;
    exit;
  end;
  visibleEnemy := 0;
end;

procedure tryFire(i: integer);
var
  j: integer;
begin
  if actors[i].fired then exit;
  j := visibleEnemy(actors[i].x, actors[i].y, actors[i].team);
  if j = 0 then exit;
  shootActor(j);
end;

procedure doAITurn(t: byte);
var
  i: integer;
  targets: array[1..100] of pactor;
  ntargets: integer;
begin
  getTeamFOV(t);

  ntargets := 0;
  for i := 1 to nactors do
    if (actors[i].team <> t) and FOVMap[actors[i].y*mapw+actors[i].x]
    then begin
      ntargets := ntargets + 1;
      targets[ntargets] := @actors[i];
    end;

  for i := 1 to nactors do begin
    if actors[i].team <> t then continue;
    tryFire(i);
  end;
end;

procedure draw;
const
  xo = 1;
  yo = 2;
var
  i: integer;
begin
  clrscr;

  gotoxy(1, 1);
  write('B L U E  D R I V E');

  { draw map }
  for i := 0 to mapw*maph-1 do begin
    gotoxy(i mod mapw + xo, i div mapw + yo);
    if (mode = mode_move) and FOVMap[i] then begin write('*'); continue; end;
    case map[i] of
      0: if FOVMap[i] then write('.') else write(' ');
      1: write('#');
      2: write('+');
    end;
  end;

  { draw actors }
  for i := 1 to nactors do
    if FOVMap[actors[i].y*mapw+actors[i].x] then begin
      gotoxy(actors[i].x+xo, actors[i].y+yo);
      if actors[i].team = playerTeam then write('D')
      else write('d');
    end;

  gotoxy(sidebarX, sidebarTopY);
  write('Turn: ', turn);
  gotoxy(sidebarX, sidebarTopY+2);
  write('d) end turn q) quit');

  case mode of
    mode_look: begin
      i := actorAt(cursorX, cursorY);
      gotoxy(sidebarX, sidebarY);
      write('(', cursorX, ',', cursorY, ') ');

      if (i <> 0) and FOVMap[cursorY*mapw+cursorX] then begin
        gotoxy(sidebarX, sidebarY+1);
        if actors[i].team = playerTeam then write('Player Unit')
        else write('Enemy unit');
        gotoxy(sidebarX, sidebarY+2);
        write('Team: ', actors[i].team);
        gotoxy(sidebarX, sidebarY+3);
        write('HP: ', actors[i].hp, '/', maxHP);
        if actors[i].team = playerTeam then begin
          gotoxy(sidebarX, sidebarY+5);
          if not actors[i].moved then write('m) move ');
          if not actors[i].fired then write('f) fire ');
        end;

      end else begin
        gotoxy(sidebarX, sidebarY+1);
        case map[cursorY*mapw+cursorX] of
          0: write('Floor');
          1: write('Wall');
          2: write('Door');
        end;
        if FOVMap[cursorY*mapw+cursorX] then write(' (visible)')
        else write(' (not visible)');
      end;
    end;

    mode_move: begin
      gotoxy(actors[selected].x+xo, actors[selected].y+yo);
      write('D');

      gotoxy(sidebarX, sidebarY);
      if FOVMap[cursorY*mapw+cursorX] then write('m) move ');
      write('c) cancel ');
    end;

    mode_fire: begin
      gotoxy(sidebarX, sidebarY);
      i := actorAt(cursorX, cursorY);
      if i <> 0 then
        if (actors[i].team <> playerTeam)
            and sees(actors[selected].x, actors[selected].y,
                     actors[i].x, actors[i].y)
        then
          write('f) fire ');
      write('c) cancel ');
    end;
  end;

  gotoxy(cursorX+xo, cursorY+yo);
end;

function control: boolean;
var
  i: integer;
begin
  control := false;
  case readkey of
    { move cursor }
    'h': if cursorX > 0 then cursorX := cursorX - 1;
    'j': if cursorY < maph-1 then cursorY := cursorY + 1;
    'k': if cursorY > 0 then cursorY := cursorY - 1;
    'l': if cursorX < mapw-1 then cursorX := cursorX + 1;
    #0: case readkey of
      #75: if cursorX > 0 then cursorX := cursorX - 1;
      #80: if cursorY < maph-1 then cursorY := cursorY + 1;
      #72: if cursorY > 0 then cursorY := cursorY - 1;
      #77: if cursorX < mapw-1 then cursorX := cursorX + 1;
    end;
    { quit }
    'q': control := true;
    { move }
    'm': if mode = mode_look then begin
      i := actorAt(cursorX, cursorY);
      if i = 0 then exit;
      if actors[i].team <> playerTeam then exit;
      if actors[i].moved then exit;
      selected := i;
      mode := mode_move;
      getActorMov(@actors[selected]);
    end else if mode = mode_move then begin
      if not FOVMap[cursorY*mapw+cursorX] then exit;
      actors[selected].x := cursorX;
      actors[selected].y := cursorY;
      actors[selected].moved := true;
      getTeamFOV(playerTeam);
      mode := mode_look;
    end;
    { fire }
    'f': if mode = mode_look then begin
      i := actorAt(cursorX, cursorY);
      if i = 0 then exit;
      if actors[i].team <> playerTeam then exit;
      if actors[i].fired then exit;
      selected := i;
      mode := mode_fire;
    end else if mode = mode_fire then begin
      i := actorAt(cursorX, cursorY);
      if i = 0 then exit;
      if actors[i].team = playerTeam then exit;
      if not sees(actors[selected].x, actors[selected].y,
                  actors[i].x, actors[i].y) then exit;
      shootActor(i);
      actors[selected].fired := true;
      mode := mode_look;
    end;
    { cancel }
    'c': begin getTeamFOV(playerTeam); mode := mode_look; end;
    { end turn }
    'd': begin
      turn := turn + 1;
      readyTeam(enemyTeam);
      doAITurn(enemyTeam);
      getTeamFOV(playerTeam);
      readyTeam(playerTeam);
    end;
  end;
end;

begin
  loadMap(map1w, map1h, map1);
  getTeamFOV(playerTeam);
  while true do begin
    draw;
    if control then break;
  end;
  clrscr;
end.

