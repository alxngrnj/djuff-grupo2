# Sistema de batalha

- `battle.gd` / `scenes/battle/battle.tscn` — cena de batalha (tudo montado por código). Rode com F6 para testar sozinha.
- `battle_launcher.gd` (autoload `BattleLauncher`) — `await BattleLauncher.start_battle(encounter)` abre a batalha por cima do mundo.
- `player_data.gd` (autoload `PlayerData`) — HP/FP, ações desbloqueadas e qual ação está em cada botão (A/B/X/Y).
- `action_database.gd` — catálogo de ações. Nova ação = uma linha em `_build()`.
- `enemy_database.gd` — catálogo de inimigos. Novo inimigo = uma linha em `_build()`.
- `../action_command.gd` — os minigames de timing (barra, sincronizado, defesa, mash).

Controles na batalha: botões A/B/X/Y = J/K/U/I ou Z/X/C/V (ou A/B/X/Y do controle); esquerda/direita trocam o alvo.
Menu do personagem no mundo: Tab (ou Select do controle).
