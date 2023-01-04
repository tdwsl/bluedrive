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
    1,2,1,1,2,1,1,2,2,1,1,1,0,0,1,
    1,0,0,0,0,0,0,0,0,2,0,0,0,4,1,
    1,2,1,1,2,1,1,0,0,1,1,2,1,1,1,
    1,0,0,4,0,0,2,0,0,2,0,0,0,0,1,
    1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
  );

  maxHP = 3;
  playerTeam = 1;
  sidebarX = 51;
  sidebarY = 3;
  sidebarTopY = 1;
  defAP = 16;

type
  actor = record
    x, y: integer;
    hp, ap: byte;
    team: byte;
  end;
  pactor = ^actor;

var
  mapw, maph: integer;
  map: array[0..3999] of byte;
  FOVMap: array[0..3999] of boolean;
  actors: array[1..70] of actor;
  nactors: integer;
  cursorX, cursorY: integer;
  turn: integer;

procedure addActor(x, y: integer; team: byte);
begin
  nactors := nactors + 1;
  actors[nactors].x := x;
  actors[nactors].y := y;
  actors[nactors].team := team;
  actors[nactors].hp := maxHP;
  actors[nactors].ap := defAP;
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

procedure draw;
var
  i: integer;
begin
  clrscr;

  { draw map }
  for i := 0 to mapw*maph-1 do begin
    gotoxy(i mod mapw + 1, i div mapw + 1);
    case map[i] of
      0: if FOVMap[i] then write('.') else write(' ');
      1: write('#');
      2: write('+');
    end;
  end;

  { draw actors }
  for i := 1 to nactors do
    if FOVMap[actors[i].y*mapw+actors[i].x] then begin
      gotoxy(actors[i].x+1, actors[i].y+1);
      if actors[i].team = playerTeam then write('D')
      else write('d');
    end;

  gotoxy(sidebarX, sidebarTopY);
  write('Turn: ', turn);

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
      gotoxy(sidebarX, sidebarY+3);
      write('AP: ', actors[i].ap, '/', defAP);
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

  gotoxy(cursorX+1, cursorY+1);
end;

function control: boolean;
begin
  control := false;
  case readkey of
    { move cursor }
    'h': if cursorX > 0 then cursorX := cursorX - 1;
    'j': if cursorY < maph-1 then cursorY := cursorY + 1;
    'k': if cursorY > 0 then cursorY := cursorY - 1;
    'l': if cursorX < mapw-1 then cursorX := cursorX + 1;
    { quit }
    'q': control := true;
  end;
end;

begin
  loadMap(map1w, map1h, map1);
  getTeamFov(1);
  while true do begin
    draw;
    if control then break;
  end;
end.

