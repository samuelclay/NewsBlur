"""Tests for slot-named Prometheus multiprocess files. utils/test_prometheus_worker_slots.py

These fork real processes, because the behaviour under test only exists across
process boundaries: a recycled worker has to reopen a dead worker's files and
resume their counters rather than start its own.
"""

import os
import shutil
import tempfile

from django.test import SimpleTestCase
from prometheus_client import CollectorRegistry, Counter, Histogram, multiprocess
from prometheus_client.mmap_dict import MmapedDict

from utils.prometheus_worker_slots import (
    discard_corrupt_slot_files,
    lowest_free_slot,
    use_worker_slot,
)

REQUESTS_PER_WORKER = 25
OBSERVED_LATENCY = 0.25


class Worker:
    """A forked stand-in for a Gunicorn worker, killed abruptly like an OOM kill.

    Constructing one blocks until the child has bound its slot and recorded its
    requests, so a test never races a worker that is still booting.
    """

    def __init__(self, prom_dir, slot, requests=REQUESTS_PER_WORKER):
        self.slot = slot
        exit_read_fd, exit_write_fd = os.pipe()
        ready_read_fd, ready_write_fd = os.pipe()

        pid = os.fork()
        if pid:
            self.pid = pid
            self.exit_write_fd = exit_write_fd
            os.close(exit_read_fd)
            os.close(ready_write_fd)
            os.read(ready_read_fd, 1)  # Wait until the worker is fully up.
            os.close(ready_read_fd)
            return

        # Child: a fresh worker booting on the slot the master handed it.
        os.close(exit_write_fd)
        os.close(ready_read_fd)
        os.environ["PROMETHEUS_MULTIPROC_DIR"] = prom_dir
        use_worker_slot(prom_dir, slot)

        registry = CollectorRegistry()
        requests_total = Counter("nb_test_requests", "requests", registry=registry)
        latency = Histogram("nb_test_latency", "latency", registry=registry)
        for _ in range(requests):
            requests_total.inc()
            latency.observe(OBSERVED_LATENCY)

        os.write(ready_write_fd, b"x")  # Slot bound, requests recorded.
        os.read(exit_read_fd, 1)  # Hold the slot until the test retires this worker.
        os._exit(0)  # No cleanup at all, exactly like a kill -9.

    def retire(self):
        os.write(self.exit_write_fd, b"x")
        os.close(self.exit_write_fd)
        os.waitpid(self.pid, 0)


class Arbiter:
    """Models the Gunicorn master: slots come from the live-worker set."""

    def __init__(self, prom_dir):
        self.prom_dir = prom_dir
        self.workers = {}

    def spawn(self):
        slot = lowest_free_slot(worker.slot for worker in self.workers.values())
        worker = Worker(self.prom_dir, slot)
        self.workers[worker.pid] = worker
        return worker

    def reap(self, worker):
        worker.retire()
        del self.workers[worker.pid]

    def live_slots(self):
        return [worker.slot for worker in self.workers.values()]

    def reap_all(self):
        for worker in list(self.workers.values()):
            self.reap(worker)


def scrape(prom_dir):
    """Collect merged multiprocess metrics the way the /metrics endpoint does."""
    registry = CollectorRegistry()
    multiprocess.MultiProcessCollector(registry, path=prom_dir)
    samples = {}
    for metric in registry.collect():
        for sample in metric.samples:
            samples[sample.name] = sample.value
    return samples


def db_files(prom_dir):
    return sorted(name for name in os.listdir(prom_dir) if name.endswith(".db"))


class Test_LowestFreeSlot(SimpleTestCase):
    def test_first_worker_takes_slot_zero(self):
        self.assertEqual(lowest_free_slot([]), 0)

    def test_next_worker_takes_the_next_slot(self):
        self.assertEqual(lowest_free_slot([0, 1, 2]), 3)

    def test_a_reaped_workers_slot_is_reused(self):
        """The gap left by a dead worker is exactly what the replacement should take."""
        self.assertEqual(lowest_free_slot([0, 2, 3]), 1)


class Test_PrometheusWorkerSlots(SimpleTestCase):
    def setUp(self):
        self.prom_dir = tempfile.mkdtemp()
        self.addCleanup(shutil.rmtree, self.prom_dir, ignore_errors=True)

    def test_live_workers_never_share_a_slot(self):
        """Two live workers on one slot would write the same mmap file and corrupt it."""
        arbiter = Arbiter(self.prom_dir)
        try:
            for _ in range(6):
                arbiter.spawn()
                slots = arbiter.live_slots()
                self.assertEqual(len(slots), len(set(slots)), f"slot shared by live workers: {slots}")

            # Retire two workers from the middle, freeing slots 1 and 3.
            live = list(arbiter.workers.values())
            arbiter.reap(live[1])
            arbiter.reap(live[3])
            self.assertEqual(sorted(arbiter.live_slots()), [0, 2, 4, 5])

            for _ in range(3):
                arbiter.spawn()
                slots = arbiter.live_slots()
                self.assertEqual(len(slots), len(set(slots)), f"slot shared by live workers: {slots}")
        finally:
            arbiter.reap_all()

    def test_recycled_worker_resumes_the_dead_workers_counters(self):
        """The whole point: reusing a slot preserves totals instead of restarting them."""
        arbiter = Arbiter(self.prom_dir)
        arbiter.reap(arbiter.spawn())
        self.assertEqual(scrape(self.prom_dir)["nb_test_requests_total"], REQUESTS_PER_WORKER)

        arbiter.reap(arbiter.spawn())

        samples = scrape(self.prom_dir)
        self.assertEqual(samples["nb_test_requests_total"], REQUESTS_PER_WORKER * 2)
        self.assertEqual(samples["nb_test_latency_count"], REQUESTS_PER_WORKER * 2)
        self.assertAlmostEqual(samples["nb_test_latency_sum"], REQUESTS_PER_WORKER * 2 * OBSERVED_LATENCY)
        self.assertEqual(db_files(self.prom_dir), ["counter_0.db", "histogram_0.db"])

    def test_rolling_recycles_never_decrease_the_counter(self):
        """A partial counter decrease reads as a reset to Prometheus and corrupts rate()."""
        arbiter = Arbiter(self.prom_dir)
        for _ in range(6):
            arbiter.spawn()

        served = 6 * REQUESTS_PER_WORKER
        previous = scrape(self.prom_dir)["nb_test_requests_total"]

        for _ in range(20):
            arbiter.reap(list(arbiter.workers.values())[0])  # Oldest hits max_requests.
            arbiter.spawn()  # Master replaces it.
            served += REQUESTS_PER_WORKER

            current = scrape(self.prom_dir)["nb_test_requests_total"]
            self.assertGreaterEqual(current, previous, "counter went backwards: Prometheus sees a reset")
            previous = current

        arbiter.reap_all()
        self.assertEqual(scrape(self.prom_dir)["nb_test_requests_total"], served)

    def test_file_count_stays_bounded_across_many_recycles(self):
        """Pid-named files grow without bound; slot-named files must not."""
        arbiter = Arbiter(self.prom_dir)
        for _ in range(30):
            arbiter.reap(arbiter.spawn())

        self.assertEqual(db_files(self.prom_dir), ["counter_0.db", "histogram_0.db"])
        self.assertEqual(scrape(self.prom_dir)["nb_test_requests_total"], 30 * REQUESTS_PER_WORKER)

    def test_file_count_tracks_peak_concurrency(self):
        arbiter = Arbiter(self.prom_dir)
        try:
            for _ in range(4):
                arbiter.spawn()
        finally:
            arbiter.reap_all()

        expected = [f"counter_{slot}.db" for slot in range(4)]
        expected += [f"histogram_{slot}.db" for slot in range(4)]
        self.assertEqual(db_files(self.prom_dir), sorted(expected))

    def test_corrupt_slot_file_is_discarded_before_reuse(self):
        """A corrupt file must not outlive the worker that corrupted it."""
        corrupt = os.path.join(self.prom_dir, "counter_0.db")
        with open(corrupt, "wb") as corrupt_file:
            corrupt_file.write(b"not an mmapped dict")
        healthy = os.path.join(self.prom_dir, "counter_1.db")
        MmapedDict(healthy).close()

        discard_corrupt_slot_files(self.prom_dir, 0)

        self.assertFalse(os.path.exists(corrupt))
        self.assertTrue(os.path.exists(healthy), "another slot's file must be left alone")

    def test_corrupt_file_from_a_dead_worker_does_not_break_the_next_worker(self):
        with open(os.path.join(self.prom_dir, "counter_0.db"), "wb") as corrupt_file:
            corrupt_file.write(b"not an mmapped dict")

        arbiter = Arbiter(self.prom_dir)
        arbiter.reap(arbiter.spawn())

        self.assertEqual(scrape(self.prom_dir)["nb_test_requests_total"], REQUESTS_PER_WORKER)
