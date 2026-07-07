# wsl2-devkit — guided walkthrough (VHS)
# Render (inside WSL, from the repo root):
#   vhs demo/devkit-demo.tape        → demo/devkit-demo.gif
#
# Requires: charmbracelet/vhs + ffmpeg + ttyd, JetBrainsMono Nerd Font in WSL,
# and the CLI tools (eza, lazygit) on PATH for the real finale.
#
# Stages 1 & 2 are faithful reproductions (demo/lib/*.sh) so the whole flow fits
# in ~30s; the finale runs the REAL eza / git / lazygit in a throwaway repo.

Output demo/devkit-demo.gif

Set Shell        "bash"
Set FontFamily   "JetBrainsMono Nerd Font"
Set FontSize     22
Set Width        1200
Set Height       750
Set Padding      30
Set WindowBar    Colorful
Set Theme        "Catppuccin Frappe"
Set TypingSpeed  60ms

# --- setup: interactive shell + one silent sourced line, then clear ---------
Hide
Type "exec bash -i"
Enter
Sleep 900ms
Type "source demo/lib/setup.sh"
Enter
Sleep 500ms
Type "clear"
Enter
Show
Sleep 600ms

# ---------------------------------------------------------------------------
# INTRO
# ---------------------------------------------------------------------------
Type@40ms "# wsl2-devkit — turn a fresh Windows box into a pro WSL2 dev setup"
Enter
Sleep 1s
Type@40ms "#   git clone https://github.com/you/wsl2-devkit && cd wsl2-devkit"
Enter
Sleep 1200ms
Type "clear"
Enter

# ---------------------------------------------------------------------------
# STAGE 1 — Windows host (reproduced)
# ---------------------------------------------------------------------------
Type "stage1"
Sleep 400ms
Enter
Sleep 4s
Type "clear"
Enter

# ---------------------------------------------------------------------------
# STAGE 2 — interactive Ubuntu toolchain (VHS drives the real prompts)
# ---------------------------------------------------------------------------
Type "stage2"
Sleep 400ms
Enter
Sleep 1400ms

Type "Y"   Sleep 250ms   Enter   Sleep 650ms
Type "Y"   Sleep 250ms   Enter   Sleep 650ms
Type "Y"   Sleep 250ms   Enter   Sleep 650ms
Type "N"   Sleep 250ms   Enter   Sleep 700ms
Type "Y"   Sleep 250ms   Enter   Sleep 650ms
Type "N"   Sleep 250ms   Enter   Sleep 650ms
Type "y"   Sleep 250ms   Enter

Sleep 3500ms
Type "clear"
Enter

# ---------------------------------------------------------------------------
# FINALE — the real, pro environment (genuine eza / git / lazygit)
# ---------------------------------------------------------------------------
Type@40ms "# your isolated, lightning-fast WSL2 environment:"
Enter
Sleep 700ms

Type "ll"          Sleep 400ms   Enter
Sleep 2s

Type "lt"          Sleep 400ms   Enter
Sleep 2200ms

Type "gl"          Sleep 400ms   Enter
Sleep 2200ms

# real lazygit TUI — Windows host stays clean, git lives in WSL
Type "lg"          Sleep 400ms   Enter
Sleep 3500ms
Type "q"

Sleep 1500ms
