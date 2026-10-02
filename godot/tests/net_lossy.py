"""A bad network between players and a host, for the online tests: a UDP relay that loses, delays and reorders packets.
    python net_lossy.py <listen ip> <port> <host ip> [loss 0.05] [delay s 0.03] [jitter s 0.02]
Every player that sends to <listen ip>:<port> gets its own socket towards <host ip>:<port>; packets both ways are dropped
with chance `loss` and arrive after delay ± jitter (so some overtake each other). Used by test_net_more.py (scenario 4)."""
import socket, select, sys, time, random, heapq

lip, port, hip = sys.argv[1], int(sys.argv[2]), sys.argv[3]
loss = float(sys.argv[4]) if len(sys.argv) > 4 else 0.05
delay = float(sys.argv[5]) if len(sys.argv) > 5 else 0.03
jitter = float(sys.argv[6]) if len(sys.argv) > 6 else 0.02
front = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
front.bind((lip, port))
backs = {}            # player address -> socket towards the host
owner = {}            # that socket -> player address
queue = []            # (time, n, socket, data, address)
n = 0
stats = {'in': 0, 'lost': 0}

def later(sock, data, addr):
    global n
    stats['in'] += 1
    if random.random() < loss:
        stats['lost'] += 1
        return
    n += 1
    heapq.heappush(queue, (time.time() + max(0.0, delay + random.uniform(-jitter, jitter)), n, sock, data, addr))

print('lossy relay', lip, port, '->', hip, 'loss', loss, 'delay', delay, 'jitter', jitter, flush=True)
last = time.time()
while True:
    wait = max(0.0, min(0.01, queue[0][0] - time.time())) if queue else 0.01
    r, _, _ = select.select([front] + list(owner), [], [], wait)
    for s in r:
        data, addr = s.recvfrom(65536)
        if s is front:
            b = backs.get(addr)
            if b is None:
                b = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
                b.bind((lip, 0))
                backs[addr] = b
                owner[b] = addr
            later(b, data, (hip, port))
        else:
            later(front, data, owner[s])
    now = time.time()
    while queue and queue[0][0] <= now:
        _, _, s, data, addr = heapq.heappop(queue)
        try:
            s.sendto(data, addr)
        except OSError:
            pass
    if now - last > 5:
        last = now
        print('relay', stats, flush=True)
