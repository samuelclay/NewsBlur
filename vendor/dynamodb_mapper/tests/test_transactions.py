from __future__ import absolute_import

from datetime import datetime
import mock
import unittest

from boto.dynamodb.exceptions import DynamoDBKeyNotFoundError
from dynamodb_mapper.model import DynamoDBModel, ConflictError,\
    MaxRetriesExceededError

from dynamodb_mapper.transactions import Transaction, TargetNotFoundError


USER_ID = 1
ENERGY = 10


class User(DynamoDBModel):
    __table__ = "user"
    __hash_key__ = "id"
    __schema__ = {
        "id": unicode,
        "energy": int
    }

class Reward(DynamoDBModel):
    __table__ = "rewards"
    __hash_key__ = u'user_id'
    __range_key__ = u'name'
    __schema__ = {
        'user_id': int,
        'name': unicode,
        'collected': bool,
    }

class InsufficientEnergyError(Exception):
    """Raised when a transaction would make a User's energy negative."""
    pass

class UniverseDestroyedError(Exception):
    """Raised when the universe ceases to exist."""
    pass

class collectRewards(Transaction):
    """A sample transaction using the new system to work on multiple targets
    It also relies on the basic schema provided in the base class.

    In this tests the getter returns a brand new object each time.

    Note that any function is supported, not only lambas.
    """
    __table__ = "rewards"

    def _get_transactors(self):
        return [
            (
                lambda: Reward(user_id=1, name=u"level up", collected=False),
                lambda target: setattr(target, "collected", True)
            ),
            (
                lambda: Reward(user_id=1, name=u"5 days", collected=False),
                lambda target: setattr(target, "collected", True)
            )
        ]

class UserEnergyTransaction(Transaction):
    """A sample transaction that adds/removes energy to a User."""
    __table__ = "energyTransaction"
    __hash_key__ = "user_id"
    __schema__ = {
        u"user_id": int,
        u"datetime": datetime,
        u"energy": int,
    }
    def _get_target(self):
        try:
            return User.get(self.user_id)
        except DynamoDBKeyNotFoundError:
            raise TargetNotFoundError(self.user_id)

    def _alter_target(self, target):
        new_energy = target.energy + self.energy
        if new_energy < 0:
            raise InsufficientEnergyError(target.energy, self.energy)
        target.energy = new_energy

class TransientUserEnergyTransaction(UserEnergyTransaction):
    """Exactly like UserEnergyTransaction, but transient (never saved to the DB)."""
    transient = True

class EnergyPurchase(Transaction):
    """A sample transaction with sub transactions"""
    __table__ = "energyPurchase"

    def _get_transactors(self):
        return [] # Stub

    def _setup(self):
        self.subtransactions.append(UserEnergyTransaction(user_id=USER_ID, energy=-ENERGY))

class TestTransaction(unittest.TestCase):
    def _get_default_user(self):
        #simulate load from DB
        return User._from_db_dict({"id": USER_ID, "energy": ENERGY})

    @mock.patch("dynamodb_mapper.model.DynamoDBModel.save")
    @mock.patch.object(User, "save")
    @mock.patch.object(User, "get")
    def test_nominal(self, m_user_get, m_user_save, m_transaction_save):
        m_user_instance = self._get_default_user()
        m_user_get.return_value = m_user_instance

        t = UserEnergyTransaction(user_id=USER_ID, energy=-ENERGY)
        t.commit()

        m_user_save.assert_called()
        m_transaction_save.assert_called()

        self.assertEquals(m_user_instance.energy, 0)
        self.assertEquals(t.user_id, USER_ID)

    @mock.patch("dynamodb_mapper.model.DynamoDBModel.save")
    @mock.patch.object(User, "save")
    @mock.patch.object(User, "get")
    def test_transient(self, m_user_get, m_user_save, m_transaction_save):
        # Transient transactions work just like regular ones wrt modifying and
        # saving their targets, but they're never saved to the DB.
        m_user_instance = self._get_default_user()
        m_user_get.return_value = m_user_instance

        # simulate "in DB" object
        t = TransientUserEnergyTransaction._from_db_dict({"user_id": USER_ID, "energy": -ENERGY})
        t.commit()

        m_user_save.assert_called()
        self.assertEquals(m_transaction_save.call_count, 0)

        self.assertEquals(m_user_instance.energy, 0)
        self.assertEquals(t.status, "done")

    @mock.patch("dynamodb_mapper.transactions.Transaction.save")
    @mock.patch("dynamodb_mapper.model.DynamoDBModel.save")
    @mock.patch("dynamodb_mapper.transactions.Transaction._setup")
    def test_setup_fails(self, m_setup, m_save, m_transaction_save):
        # When the setup phase fails, nothing must be called, and nothing must be saved.
        m_setup.side_effect = UniverseDestroyedError("ONOZ!")
        # simulate "in DB" object
        t = UserEnergyTransaction._from_db_dict({"user_id": USER_ID, "energy": 10})

        self.assertRaises(UniverseDestroyedError, t.commit)

        self.assertEquals(m_save.call_count, 0)
        m_transaction_save.assert_called()
        self.assertEquals(t.status, "pending")

    @mock.patch("dynamodb_mapper.transactions.Transaction.save")
    @mock.patch.object(User, "save")
    @mock.patch("dynamodb_mapper.model.DynamoDBModel.get")
    def test_target_not_found(self, m_get, m_user_save, m_transaction_save):
        m_get.side_effect = DynamoDBKeyNotFoundError("ONOZ!")
        # simulate "in DB" object
        t = UserEnergyTransaction._from_db_dict({"user_id": USER_ID, "energy": 10})

        self.assertRaises(TargetNotFoundError, t.commit)

        # The transaction fails at the first step: no save
        self.assertEquals(m_user_save.call_count, 0)
        self.assertFalse(m_transaction_save.called)
        self.assertEquals(t.status, "pending")

    @mock.patch("dynamodb_mapper.transactions.Transaction.save")
    @mock.patch.object(User, "save")
    @mock.patch.object(User, "get")
    def test_insufficient_energy(self, m_user_get, m_user_save, m_transaction_save):
        m_user_instance = self._get_default_user()
        m_user_get.return_value = m_user_instance
        # simulate "in DB" object
        t = UserEnergyTransaction._from_db_dict({"user_id": USER_ID, "energy": -ENERGY * 2})

        self.assertRaises(InsufficientEnergyError, t.commit)

        self.assertEquals(m_user_instance.energy, ENERGY)
        self.assertEquals(m_user_save.call_count, 0)
        self.assertFalse(m_transaction_save.called)
        self.assertEquals(t.status, "pending")

    @mock.patch("dynamodb_mapper.transactions.Transaction.save")
    @mock.patch.object(User, "save")
    @mock.patch.object(User, "get")
    def test_race_condition(self, m_user_get, m_user_save, m_transaction_save):
        # Fail 10 times before allowing the save to succeed
        failed_tries = 10
        def save_side_effect(*args, **kw):
            if m_user_save.call_count < failed_tries:
                raise ConflictError()

        # Return a clean user every time -- we will be retrying a lot.
        m_user_get.side_effect = lambda *args, **kw: self._get_default_user()
        m_user_save.side_effect = save_side_effect

        # simulate "in DB" object
        t = UserEnergyTransaction._from_db_dict({"user_id": USER_ID, "energy": -ENERGY})

        t.commit()
        m_transaction_save.assert_called()
        self.assertEquals(t.status, "done")
        self.assertEqual(m_user_save.call_count, failed_tries)

    @mock.patch("dynamodb_mapper.transactions.Transaction.save")
    @mock.patch.object(User, "save")
    @mock.patch.object(User, "get")
    def test_max_retries_exceeded(self, m_user_get, m_user_save, m_transaction_save):
        # Return a clean user every time -- we will be retrying a lot.
        m_user_get.side_effect = lambda *args, **kw: self._get_default_user()
        m_user_save.side_effect = ConflictError()

        # simulate "in DB" object
        t = UserEnergyTransaction._from_db_dict({"user_id": USER_ID, "energy": ENERGY})

        self.assertRaises(MaxRetriesExceededError, t.commit)
        self.assertEquals(m_user_save.call_count, Transaction.MAX_RETRIES)
        m_transaction_save.assert_called()
        self.assertEquals(t.status, "pending")

    def test_get_2_transactors(self):
        t = collectRewards()
        transactors = t._get_transactors()

        self.assertEquals(len(transactors), 2)

    def test_legacy_get_transactors(self):
        t = UserEnergyTransaction()
        transactors = t._get_transactors()

        self.assertEquals(len(transactors), 1)
        self.assertEquals(transactors[0][0], t._get_target)
        self.assertEquals(transactors[0][1], t._alter_target)

    @mock.patch("dynamodb_mapper.transactions.Transaction.save")
    @mock.patch("dynamodb_mapper.model.Item")
    @mock.patch("dynamodb_mapper.model.boto")
    #@mock.patch.object(Reward, "save")
    def test_commit_2_targets(self, m_boto_, m_item, m_transaction_save):
        m_item_instance = m_item.return_value

        t = collectRewards()
        t.commit()

        #Check "allow_overwrite=False" was generated correctly
        m_item_instance.put.assert_called_with({u'user_id': False, u'name': False})
        self.assertEquals(m_item_instance.put.call_count, 2)

        self.assertEquals(t.status, "done")

    @mock.patch("dynamodb_mapper.model.DynamoDBModel.save")
    @mock.patch.object(UserEnergyTransaction, "commit")
    @mock.patch.object(User, "get")
    def test_subtransactions(self, m_user_get, m_energy_commit, m_transaction_save):
        m_user_instance = self._get_default_user()
        m_user_get.return_value = m_user_instance

        EnergyPurchase().commit()

        m_energy_commit.assert_called()

