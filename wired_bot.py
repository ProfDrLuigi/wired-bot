#!/usr/bin/env python3
"""
Simple Wired 2.0 console chat listener with watchdog support.

Connects to a Wired server, joins public chat (ID 1), and prints
incoming chat messages (say/me) to stdout. Also prints topic changes
and basic join/leave notifications. No GUI, no input.

Additionally supports watching a directory for new files and sending
their contents to the chat.

Usage example:
  python examples/console_chat.py \
      --host 127.0.0.1 --port 4871 \
      --user guest --password "" \
      --nick ConsoleUser --status "" \
      --script /path/to/handler.sh \
      --socket /tmp/wired_public.sock \
      --watch-dir /path/to/watch
"""

import argparse
import logging
import sys
import time
import os
import shlex
import socket
import threading
import subprocess
import queue
from typing import Dict, Optional, Set
from pathlib import Path

from wired2 import P7Spec, P7Message
from wired2.block_connection import BlockConnection

# Import watchdog components
try:
    from watchdog.observers import Observer
    from watchdog.events import FileSystemEventHandler, FileCreatedEvent, FileModifiedEvent
    WATCHDOG_AVAILABLE = True
except ImportError:
    WATCHDOG_AVAILABLE = False

def eprint(*args, **kwargs):
    print(*args, file=sys.stderr, **kwargs)


def daemonize() -> None:
    """Daemonize this process using the classic double-fork (POSIX only)."""
    if os.name != "posix":
        return
    try:
        pid = os.fork()
        if pid > 0:
            # Exit parent of first fork
            os._exit(0)
    except OSError as e:
        eprint(f"[ERROR] First fork failed: {e}")
        sys.exit(1)

    # Detach from terminal and create new session
    os.setsid()

    try:
        pid = os.fork()
        if pid > 0:
            # Exit parent of second fork
            os._exit(0)
    except OSError as e:
        eprint(f"[ERROR] Second fork failed: {e}")
        sys.exit(1)

    # Redirect stdio to /dev/null
    try:
        sys.stdout.flush()
        sys.stderr.flush()
    except Exception:
        pass
    try:
        with open("/dev/null", "rb", 0) as fnull_in, open("/dev/null", "ab", 0) as fnull_out:
            os.dup2(fnull_in.fileno(), sys.stdin.fileno())
            os.dup2(fnull_out.fileno(), sys.stdout.fileno())
            os.dup2(fnull_out.fileno(), sys.stderr.fileno())
    except Exception:
        # Best-effort; ignore if /dev/null unavailable
        pass
        

class WiredFileHandler(FileSystemEventHandler):
    """Handles file system events and sends file contents to Wired chat."""

    def __init__(self, conn: BlockConnection, chat_id: int = 1, 
                 watch_modified: bool = False,
                 prefix: str = "",
                 processed_files: Optional[Set[str]] = None):
        self.conn = conn
        self.chat_id = chat_id
        self.watch_modified = watch_modified
        self.prefix = prefix
        self.processed_files = processed_files or set()
        self.lock = threading.Lock()

    def process_file(self, path: str) -> None:
        """Read file or directory and send line (and content if file) to chat."""
        with self.lock:
            if not self.watch_modified and path in self.processed_files:
                return
            self.processed_files.add(path)

        try:
            file_path = Path(path)

            # Ignore non-existent paths
            if not file_path.exists():
                return

            # Ignore temporary runc-process files
            if file_path.name.startswith("runc-process"):
                return

            # Send filename to chat
            line = f"{self.prefix}[File: {file_path.name}]"
            try:
                self.conn.send_chat_say(self.chat_id, line)
            except Exception as e:
                eprint(f"[WATCHDOG] Failed to send line: {e}")
                return

        except Exception as e:
            eprint(f"[WATCHDOG] Error processing {path}: {e}")

    def on_created(self, event):
        """Handle creation events for files or directories."""
        if not event.is_directory or event.is_directory:
            time.sleep(0.5)  # Wait briefly for file/dir to settle
            self.process_file(event.src_path)

    def on_modified(self, event):
        """Handle modifications if watch_modified is True."""
        if self.watch_modified:
            time.sleep(0.5)
            self.process_file(event.src_path)

def main() -> int:
    parser = argparse.ArgumentParser(description="Wired 2.0 console chat listener")
    parser.add_argument("--host", default="127.0.0.1", help="Server host")
    parser.add_argument("--port", type=int, default=4871, help="Server port")
    # Accept both --user and --username for consistency with the TUI client
    parser.add_argument("--user", "--username", dest="user", default="guest", help="Username (auth login)")
    parser.add_argument("--password", default="", help="Password")
    parser.add_argument("--nick", default="WiredUser", help="Nickname")
    parser.add_argument("--status", default="", help="Status message")
    parser.add_argument("--script", default=None, help="Path to a program/script to execute for each public chat line. The chat line is passed as the first argument.")
    parser.add_argument("--icon", default=None, help="Path to a PNG icon to set before login.")
    parser.add_argument(
        "--socket",
        dest="socket_path",
        default=None,
        help="Path to a Unix domain socket. Text written to this socket is sent to public chat (ID 1).",
    )
    parser.add_argument("--watch-dir", default=None, help="Directory to watch for new files")
    
    parser.add_argument("--debug", action="store_true", help="Enable debug logging")
    parser.add_argument("-D", "--daemonize", action="store_true", help="Daemonize into the background (Linux/macOS)")
    args = parser.parse_args()

    # Check watchdog availability if watch-dir is specified
    if args.watch_dir and not WATCHDOG_AVAILABLE:
        eprint("[ERROR] Watchdog functionality requested but watchdog package is not installed.")
        eprint("Please install it with: pip install watchdog")
        return 1

    # If requested, daemonize early before setting up logging/connection
    if args.daemonize:
        daemonize()

    # Optional console logging for troubleshooting
    if args.debug:
        logging.basicConfig(level=logging.DEBUG, format="[%(levelname)s] %(message)s")
    else:
        logging.basicConfig(level=logging.INFO, format="[%(levelname)s] %(message)s")

    # Prepare connection similar to the TUI client
    spec = P7Spec.load_default_wired()
    conn = BlockConnection(spec=spec)
    conn.request_encryption = True
    conn.request_checksum = True
    conn.interactive = False
    # Suppress note-only (<n>...</n>) chat messages from output
    try:
        conn.filter_note_messages = True  # type: ignore[attr-defined]
    except Exception:
        pass

    # Simple caches
    users: Dict[int, str] = {}  # uid -> nick (best effort, from user list events)
    user_logins: Dict[int, str] = {}  # uid -> wired.user.login (resolved via get_info)
    user_lock = threading.Lock()
    
    # Idle state tracking
    is_idle = False

    # Background resolver for wired.user.login lookups to avoid blocking event thread
    login_requests: "queue.Queue[int]" = queue.Queue()
    inflight: set[int] = set()

    def queue_login_lookup(uid: int) -> None:
        if uid <= 0:
            return
        with user_lock:
            if uid in user_logins or uid in inflight:
                return
            inflight.add(uid)
        try:
            login_requests.put_nowait(uid)
        except Exception:
            # If queue is full/unavailable, drop inflight marker so we can retry later
            with user_lock:
                inflight.discard(uid)

    def _resolve_login(uid: int, timeout: float = 5.0) -> Optional[str]:
        try:
            # Use BlockConnection's transaction flow to avoid read conflicts
            m = P7Message(name="wired.user.get_info", spec=spec)
            m.add_parameter("wired.user.id", int(uid))
            reply = conn.send_and_wait(m, timeout=timeout, raise_on_error=False)
            if reply is None:
                return None
            # Expect wired.user.info on success
            if getattr(reply, "name", "") == "wired.user.info":
                try:
                    login = reply.string("wired.user.login") or None
                except Exception:
                    login = None
                return login
            return None
        except Exception:
            return None

    stop_event = threading.Event()

    def login_resolver_worker() -> None:
        while not stop_event.is_set():
            try:
                uid = login_requests.get(timeout=0.5)
            except queue.Empty:
                continue
            try:
                login = _resolve_login(uid)
                with user_lock:
                    if login:
                        user_logins[uid] = login
                    inflight.discard(uid)
            except Exception:
                with user_lock:
                    inflight.discard(uid)
            finally:
                try:
                    login_requests.task_done()
                except Exception:
                    pass

    def set_idle(is_idle_state: bool) -> bool:
        """Set the client's idle status immediately via the connection.
        
        Returns True on success, False on failure.
        """
        try:
            # Prefer transactional send via BlockConnection to avoid race with listener thread
            m = P7Message(name="wired.user.set_idle", spec=spec)
            m.add_parameter("wired.user.idle", bool(is_idle_state))
            sent = False
            try:
                sent = bool(conn.send(m))
            except Exception:
                sent = False
            return sent
        except Exception as e:
            eprint(f"[ERROR] Failed to set idle state: {e}")
            return False

    # Event handlers
    def on_message_raw(message):
        # Keep minimal raw logging only when debug is enabled
        if args.debug:
            name = getattr(message, "name", "")
            logging.debug(f"RAW {name}")

    conn.on_message = on_message_raw

    def on_error(message):
        try:
            err = conn.map_error(message)
        except Exception:
            err = str(message)
        eprint(f"[ERROR] {err}")

    conn.on_error = on_error

    def on_disconnect():
        eprint("Disconnected from server")

    conn.on_disconnect = on_disconnect

    # Pre-parse script command if provided
    script_cmd = None
    if args.script:
        try:
            script_cmd = shlex.split(args.script)
            if not script_cmd:
                script_cmd = None
        except Exception:
            # Fallback: treat as a single executable path
            script_cmd = [args.script]

    # Load icon bytes if provided
    icon_bytes = None
    if args.icon:
        try:
            with open(args.icon, "rb") as f:
                icon_bytes = f.read()
            if args.debug:
                eprint(f"Loaded icon bytes from {args.icon} ({len(icon_bytes)} bytes)")
        except Exception as e:
            eprint(f"[ERROR] Failed to read icon file '{args.icon}': {e}")

    def _format_chat_line(user_id: int, text: str) -> str:
        # Prefer cached nick and login; queue login lookup if missing
        with user_lock:
            nick = users.get(user_id)
            login = user_logins.get(user_id)
        if not nick:
            nick = f"uid:{user_id}"
        if not login:
            queue_login_lookup(user_id)
            login = f"uid:{user_id}"
        return f"{nick} ||| {login} ||| {text}"

    def on_chat_say(chat_id: int, user_id: int, text: str):
        # Only process public chat (ID 1)
        if chat_id == 1:
            line = _format_chat_line(user_id, text)
            print(line, flush=True)
            # If a script is provided, execute it with the chat line as first argument
            if script_cmd:
                try:
                    subprocess.Popen(
                        [*script_cmd, line],
                        stdout=subprocess.DEVNULL,
                        stderr=subprocess.DEVNULL,
                    )
                except Exception as e:
                    eprint(f"[ERROR] Failed to execute script: {e}")

    conn.on_chat_say = on_chat_say

    # Ignore note/image events entirely in this console example
    try:
        def on_chat_note(chat_id: int, user_id: int, notes, message):
            # Intentionally do nothing; messages are filtered above
            return
        conn.on_chat_note = on_chat_note  # type: ignore[attr-defined]
    except Exception:
        pass

    def on_chat_me(chat_id: int, user_id: int, text: str):
        # Only process public chat (ID 1)
        if chat_id == 1:
            line = _format_chat_line(user_id, text)
            print(line, flush=True)
            if script_cmd:
                try:
                    subprocess.Popen(
                        [*script_cmd, line],
                        stdout=subprocess.DEVNULL,
                        stderr=subprocess.DEVNULL,
                    )
                except Exception as e:
                    eprint(f"[ERROR] Failed to execute script: {e}")

    conn.on_chat_me = on_chat_me

    def on_chat_user_join(chat_id: int, message):
        try:
            uid = message.uint32("wired.user.id") or 0
            nick = message.string("wired.user.nick") or f"User{uid}"
            with user_lock:
                users[uid] = nick
            queue_login_lookup(uid)
            # Announce joined to stdout (and script if configured) for public chat
            if int(chat_id or 0) == 1:
                line = f"joined ||| {nick}"
                print(line, flush=True)
                if script_cmd:
                    try:
                        subprocess.Popen(
                            [*script_cmd, line],
                            stdout=subprocess.DEVNULL,
                            stderr=subprocess.DEVNULL,
                        )
                    except Exception as e:
                        eprint(f"[ERROR] Failed to execute script: {e}")
        except Exception:
            pass

    conn.on_chat_user_join = on_chat_user_join

    def on_chat_user_leave(chat_id: int, arg):
        # Accept either (chat_id, user_id) or (chat_id, message) depending on wired2 version
        uid: int
        nick: Optional[str] = None
        if hasattr(arg, "uint32") and hasattr(arg, "string"):
            try:
                uid = int(arg.uint32("wired.user.id") or 0)
            except Exception:
                uid = 0
            try:
                nick = arg.string("wired.user.nick") or None
            except Exception:
                nick = None
        else:
            try:
                uid = int(arg)
            except Exception:
                uid = 0
        # Update cache and determine display name
        with user_lock:
            cached = users.pop(uid, None)
        name = nick or cached or (f"uid:{uid}" if uid else "uid:0")
        if int(chat_id or 0) == 1:
            line = f"left ||| {name}"
            print(line, flush=True)
            if script_cmd:
                try:
                    subprocess.Popen(
                        [*script_cmd, line],
                        stdout=subprocess.DEVNULL,
                        stderr=subprocess.DEVNULL,
                    )
                except Exception as e:
                    eprint(f"[ERROR] Failed to execute script: {e}")
        
    conn.on_chat_user_leave = on_chat_user_leave

    def on_chat_user_list(chat_id: int, message):
        try:
            uid = message.uint32("wired.user.id") or 0
            nick = message.string("wired.user.nick") or f"User{uid}"
            with user_lock:
                users[uid] = nick
            queue_login_lookup(uid)
        except Exception:
            pass

    conn.on_chat_user_list = on_chat_user_list

    def on_chat_topic(chat_id: int, nick: str, topic: str, when):
        # Ignore topic announcements in output
        pass

    conn.on_chat_topic = on_chat_topic

    # Connect flow (mirrors the TUI connect method)
    url = f"wired://{args.host}:{args.port}"
    eprint(f"Connecting to {url} as {args.nick} ...")
    if not conn.connect(url):
        eprint(f"Failed to connect to {url}")
        return 2

    if not conn.client_info("Wired Console", "1.0", "1"):
        eprint("Failed to send client_info")
        return 3

    if not conn.set_nick(args.nick):
        eprint("Failed to set nick")
        return 4

    if not conn.set_status(args.status or ""):
        eprint("Failed to set status")
        return 5

    # Set initial icon BEFORE login, similar to TUI client
    if icon_bytes:
        try:
            ok = conn.set_icon(icon_bytes)
            if not ok and args.debug:
                eprint("[WARN] set_icon returned False")
        except Exception as e:
            eprint(f"[ERROR] Failed to set icon: {e}")

    if not conn.login(args.user, args.password):
        eprint(f"Login failed for user '{args.user}'")
        return 6

    # Start login resolver thread before listening so it's ready for lookups
    resolver_thread = threading.Thread(target=login_resolver_worker, name="login_resolver", daemon=True)
    resolver_thread.start()

    # Start receiving events and join chat 1
    conn.start_listening()
    if not conn.join_chat(1):
        eprint("Warning: failed to join chat 1")

    eprint("Connected. Listening for chat messages (Ctrl+C to quit)...")

    # Setup watchdog if directory specified
    observer = None
    if args.watch_dir and WATCHDOG_AVAILABLE:
        watch_path = Path(args.watch_dir)
        if not watch_path.exists():
            eprint(f"[ERROR] Watch directory does not exist: {args.watch_dir}")
            return 7
        if not watch_path.is_dir():
            eprint(f"[ERROR] Watch path is not a directory: {args.watch_dir}")
            return 8
        
        # Create and configure file handler
        file_handler = WiredFileHandler(
            conn=conn,
            chat_id=1
        )
        
        # Start observer
        observer = Observer()
        observer.schedule(file_handler, str(watch_path), recursive=False)
        observer.start()
        eprint(f"[WATCHDOG] Watching directory: {watch_path}")

    # If --socket is provided, spin up a background Unix domain socket server

    def socket_server(path: str):
        srv = None
        try:
            # Remove pre-existing socket file
            try:
                if os.path.exists(path):
                    os.unlink(path)
            except Exception:
                pass

            srv = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
            # Allow quick reuse of the path if needed
            try:
                srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
            except Exception:
                pass
            srv.bind(path)
            srv.listen(5)
            # Restrict permissions a bit (best-effort; umask may already apply)
            try:
                os.chmod(path, 0o600)
            except Exception:
                pass

            while not stop_event.is_set():
                try:
                    srv.settimeout(1.0)
                    try:
                        client, _ = srv.accept()
                    except socket.timeout:
                        continue
                    with client:
                        chunks = []
                        while True:
                            data = b""
                            try:
                                data = client.recv(4096)
                            except Exception:
                                break
                            if not data:
                                break
                            chunks.append(data)
                        raw = b"".join(chunks)
                        if not raw:
                            continue
                        try:
                            text = raw.decode("utf-8", errors="replace")
                        except Exception:
                            text = raw.decode("utf-8", errors="replace")
                        # Send each non-empty line to public chat 1
                        for line in text.splitlines():
                            line = line.rstrip("\r\n")
                            if line.strip():
                                # Check if it's the /idle command
                                if line.strip().lower() == "/idle":
                                    nonlocal is_idle
                                    is_idle = not is_idle
                                    ok = set_idle(is_idle)
                                    if ok:
                                        eprint(f"[INFO] Idle state set to: {is_idle}")
                                    else:
                                        eprint("[ERROR] Failed to set idle state")
                                else:
                                    try:
                                        ok = conn.send_chat_say(1, line)
                                        if not ok:
                                            eprint("[ERROR] Failed to send chat line from socket")
                                    except Exception as e:
                                        eprint(f"[ERROR] Exception sending chat from socket: {e}")
                except Exception as e:
                    # Keep the server alive unless we're stopping
                    if not stop_event.is_set():
                        eprint(f"[ERROR] Socket server error: {e}")
        finally:
            try:
                if srv:
                    srv.close()
            except Exception:
                pass
            try:
                if os.path.exists(path):
                    os.unlink(path)
            except Exception:
                pass

    sock_thread = None
    if args.socket_path:
        try:
            sock_thread = threading.Thread(target=socket_server, args=(args.socket_path,), daemon=True)
            sock_thread.start()
            eprint(f"Unix socket listening at {args.socket_path}")
        except Exception as e:
            eprint(f"[ERROR] Failed to start socket server: {e}")

    try:
        while True:
            time.sleep(1.0)
    except KeyboardInterrupt:
        pass
    finally:
        # Stop socket thread and cleanup
        try:
            stop_event.set()
            # Also stop resolver thread
            if resolver_thread and resolver_thread.is_alive():
                resolver_thread.join(timeout=2.0)
            if sock_thread and sock_thread.is_alive():
                sock_thread.join(timeout=2.0)
        except Exception:
            pass
        try:
            conn.disconnect()
        except Exception:
            pass
    return 0


if __name__ == "__main__":
    sys.exit(main())
