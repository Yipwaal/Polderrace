"""Only the qa-reviewer agent runs this, and only after it has approved the current game file.
Records the hash of polderrace-3d.html so the Stop hook lets Claude finish."""
from lib import game_hash, OUT, TESTS

h = game_hash()
(TESTS / 'reviewed.txt').write_text(h + '\n')
(OUT / 'hook_state.json').unlink(missing_ok=True)
print('goedgekeurd:', h)
