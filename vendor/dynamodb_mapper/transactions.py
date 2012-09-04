from __future__ import absolute_import

from datetime import datetime
import logging

from dynamodb_mapper.model import (ConflictError, OverwriteError,
    MaxRetriesExceededError, utc_tz, DynamoDBModel)


log = logging.getLogger(__name__)


class TargetNotFoundError(Exception):
    """Raised when attempting to commit a transaction on a target that
    doesn't exist.
    """


class Transaction(DynamoDBModel):
    """Abstract base class for transactions. A transaction may involve multiple
    targets and needs to be fully successful to be marked as "DONE".

    This class gracefully handles concurrent modifications and auto-retries but
    embeds no tool to rollback.

    Transactions may register ``subtransactions``. This field is a list of
    ``Transaction``. Sub-transactions are played after the main transactors

    Transactions status may be persisted for tracability, further analysis...
    for this purpose, a minimal schema is embedded in this base class. When
    deriving, you MUST keep

        - ``datetime`` field as rangekey
        - ``status`` field

    The hash key field may be changed to pick a ore relevant name or change its
    type. In any case, you are responsible of setting its value. For example, if
    collecting rewards for a player, you may wish to keep track of related
    transactions by user_id hence set requester_id to user_id

    Deriving class **MUST** set field ``__table__`` and ``requester_id`` field
    """

    __hash_key__ = "requester_id"
    __range_key__ = "datetime"

    __schema__ = {
        "requester_id": int,
        "datetime": datetime,
        "status": unicode #IN("pending", "running", "done")
    }

    # Transient transactions (with this flag set to True) are not saved in the
    # database, and are as a result write-only. This value is defined on the
    # class level bu may be redefined on a per instance basis.
    transient = False

    # Maximum attempts. Each attempt consumes write credits
    MAX_RETRIES = 100

    STATUSES_TO_SAVE = frozenset(["running", "done"])

    def __init__(self, **kwargs):
        super(Transaction, self).__init__(**kwargs)
        self.subtransactions = []

    def _setup(self):
        """Set up preconditions and parameters for the transaction.

        This method is only run once, regardless of how many retries happen.
        You should override it to fetch all the *unchanging* information you
        need from the database to run the transaction (e.g. the cost of a Bingo
        card, or the contents of a reward).
        """

    def _get_transactors(self):
        """Fetch a list of targets (getter, setter) tuples. The transaction
        engine will walk the list. For each tuple, the getter and the setter are
        called successively until this step of the transaction succeed or exhaust
        the MAX_RETRIES.

            - getter: Fetch the object on which this transaction is supposed to operate
                (e.g. a User instance for UserResourceTransactions) from the DB and
                return it.
                It is important that this method actually connect to the database and
                retrieve a clean, up-to-date version of the object -- because it will
                be called repeatedly if conditional updates fail due to the target
                object having changed.
                The getter takes no argument and returns a DBModel instance

            - setter: Applyies the transaction to the target, modifying it in-place.
                Does *not* attempt to save the target or the transaction to the DB.
                The setter takes a DBModel instance as argument. Its return value is
                ignored

        The list is walked from 0 to len(transactors)-1. Depending on your application,
        Order may matter.

        :raise TargetNotFoundError: If the target doesn't exist in the DB.
        """
        #FIXME: compat method
        return [(self._get_target, self._alter_target)]

    def _get_target(self):
        """Legacy"""
        #FIXME: legacy

    def _alter_target(self, target):
        """Legacy"""
        #FIXME: legacy

    def _apply_and_save_target(self, getter, setter):
        """Apply the Transaction and attempt to save its target (but not
        the Transaction itself). May be called repeatedly until it stops
        raising :exc:`ConflictError`.

        Will succeed iff no attributes of the object returned by getter has been
        modified before ou save method to prevent accidental overwrites.

        :param getter: getter as defined in :py:meth:`_get_transactors`
        :param setter: setter as defined in :py:meth:`_get_transactors`

        :raise ConflictError: If the target is changed by an external
            source (other than the Transaction) between its retrieval from
            the DB and the save attempt.
        """
        # load base object
        target = getter()

        # edit and attempt to save it
        setter(target)

        # If we've reached this point, at least the transaction's primary
        # target exists, and will have been modified/saved even if the rest
        # of the transaction fails.

        # So if anything fails beyond this point, we must save the transaction.
        target.save(raise_on_conflict=True)
        self.status = "running"

    def _apply_subtransactions(self):
        """Run sub-transactions if applicable. This is called after the main
        transactors.

        This code has been moved to its own method to ease overloading in
        real-world applications without re-implementing the whole ``commit``
        logic.

        This method should *not* be called directly. It may only be overloaded
        to handle special behaviors like callbacks.
        """
        for subtransaction in self.subtransactions:
            subtransaction.commit()

    def _assign_datetime_and_save(self):
        """Auto-assign a datetime to the Transaction (it's its range key)
        and attempt to save it. May be called repeatedly until it stops raising
        :exc:`OverwriteError`.

        :raise OverwriteError: If there already exists a Transaction with that
            (user_id, datetime) primary key combination.
        """
        self.datetime = datetime.now(utc_tz)
        self.save(raise_on_conflict=True)

    def _retry(self, fn, exc_class):
        """Call ``fn`` repeatedly, until it stops raising
        ``exc_class`` or it has been called ``MAX_RETRIES`` times (in which case
        :exc:`MaxRetriesExceededError` is raised).

        :param fn: The callable to retry calling.
        :param exc_class: An exception class (or tuple thereof) that, if raised
            by fn, means it has failed and should be called again.
            *Any other exception will propagate normally, cancelling the
            auto-retry process.*
        """
        tries = 0
        while tries < self.MAX_RETRIES:
            tries += 1
            try:
                fn()
                # Nothing was raised: we're done !
                break
            except exc_class as e:
                log.debug(
                    "%s %s=%s: exception=%s in fn=%s. Retrying (%s).",
                    type(self),
                    self.__hash_key__,
                    getattr(self, self.__hash_key__),
                    e,
                    fn,
                    tries)
        else:
            raise MaxRetriesExceededError()

    def commit(self):
        """ Run the transaction and, if needed, store its states to the database

            - set up preconditions and parameters (:meth:`_setup` -- only called
              once no matter what).
            - fetch all transaction steps (:meth:`_get_transactors`).
            - for each transaction :

                - fetch the target object from the DB.
                - modify the target object according to the transaction's parameters.
                - save the (modified) target to the DB

            - run sub-transactions (if any)
            - save the transaction to the DB

        Each transation may be retried up to ``MAX_RETRIES`` times automatically.
        commit uses conditional writes to avoid overwriting data in the case of
        concurrent transactions on the same target (see :meth:`_retry`).
        """

        try:
            self.status = "pending"

            self._setup()
            transactors = self._get_transactors()

            for getter, setter in transactors:
                self._retry(
                    lambda: self._apply_and_save_target(getter, setter),
                    ConflictError)

            self._apply_subtransactions()

            self.status = "done"
        finally:
            if self.status in self.STATUSES_TO_SAVE:
                # Save the transaction if it succeeded,
                # or if it failed partway through.
                self._retry(self._assign_datetime_and_save, OverwriteError)

    def save(self, raise_on_conflict=True):
        """If the transaction is transient (``transient = True``),
        do nothing.

        If the transaction is persistent (``transient = False``), save it to
        the DB, as :meth:`DynamoDBModel.save`.

        Note: this method is called automatically from ``commit``. You may but do
        not need to call it explicitly.
        """
        if self.transient:
            log.debug(
                "class=%s: Transient transaction, ignoring save attempt.",
                type(self))
        else:
            super(Transaction, self).save(raise_on_conflict=raise_on_conflict)

