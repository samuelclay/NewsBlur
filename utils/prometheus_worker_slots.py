"""Bound Prometheus multiprocess files by naming them after a worker slot.

utils/prometheus_worker_slots.py

In multiprocess mode prometheus_client names each worker's metric files after its
pid (counter_<pid>.db, histogram_<pid>.db). Gunicorn recycles workers every
max_requests, and counter and histogram files are never deleted, because their
values belong to the cumulative total. On a busy host that leaves thousands of
dead-worker files, and every /metrics scrape mmaps and merges all of them. The
collector adds one Sample per key per file before deduplicating, so its peak
memory grows with files x keys: roughly 400MB per scrape at 1,900 files, which is
enough to get a Gunicorn worker OOM-killed.

Naming the files after a worker slot fixes this at the source. MultiProcessValue
accepts any process identifier as long as simultaneously running workers get
distinct ones, so the Gunicorn master hands each worker the lowest slot no live
worker holds. A recycled worker inherits the dead worker's slot, reopens its
files, and resumes their counters. The file count is then bounded by peak worker
concurrency instead of growing with every worker that has ever run, no file is
ever deleted, totals stay exact, and counters never appear to reset.

Slots are assigned in the master rather than claimed with a lock file on purpose.
flock is not enforced on every filesystem the metrics directory can sit on: on a
macOS Docker bind mount two workers are both granted the same exclusive lock,
which would quietly point them at one mmap file and corrupt it.
"""

import logging
import os

from prometheus_client import values
from prometheus_client.mmap_dict import MmapedDict

logger = logging.getLogger(__name__)


def lowest_free_slot(taken_slots):
    """Return the smallest slot index that no live worker is using."""
    taken = set(taken_slots)
    slot = 0
    while slot in taken:
        slot += 1
    return slot


def discard_corrupt_slot_files(prom_dir, slot):
    """Delete this slot's metric files if the previous worker left them unreadable.

    Inheriting a slot means inheriting its files, so a corrupt file would
    otherwise outlive the worker that corrupted it and break every later scrape.
    Only the worker that owns the slot gets here, so removing them is safe, and
    losing one slot's history beats an unreadable metrics endpoint.
    """
    slot_suffix = f"_{slot}.db"
    try:
        filenames = os.listdir(prom_dir)
    except OSError as e:
        logger.error(f"Could not scan Prometheus directory {prom_dir}: {e}")
        return

    for filename in filenames:
        if not filename.endswith(slot_suffix):
            continue

        filepath = os.path.join(prom_dir, filename)
        try:
            list(MmapedDict.read_all_values_from_file(filepath))
        except Exception as e:
            logger.warning(f"Discarding corrupt Prometheus file {filepath}: {e}")
            try:
                os.unlink(filepath)
            except OSError as unlink_error:
                logger.error(f"Could not remove corrupt Prometheus file {filepath}: {unlink_error}")


def use_worker_slot(prom_dir, slot):
    """Point this worker's metric files at its slot instead of its pid.

    Must run before any metric is constructed, since prometheus_client binds a
    metric to a file the moment the metric is created.
    """
    discard_corrupt_slot_files(prom_dir, slot)
    values.ValueClass = values.MultiProcessValue(process_identifier=lambda: slot)
