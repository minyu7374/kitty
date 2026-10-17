from pathlib import Path
import os

from kittens.tui.handler import result_handler


def main(args):
    pass


@result_handler(no_ui=True)
def handle_result(args, result, target_window_id, boss):
    runtime_dir = Path(os.environ.get('XDG_RUNTIME_DIR') or os.environ.get('XDG_CACHE_HOME', str(Path.home() / '.cache')))
    runtime_dir.mkdir(parents=True, exist_ok=True)
    (runtime_dir / 'smart-splits-herdr-kitty').write_text(f'{boss.listening_on}\n{target_window_id}\n')
    boss.window_id_map[target_window_id].send_key(args[1])
