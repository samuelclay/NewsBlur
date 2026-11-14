"""Every migration must keep working with the code already in production.

Deploys run `migrate` from the new code before any server restarts (ansible/playbooks/deploy_migrate.yml), so
for the rest of the deploy, and after any rollback, the previous release runs against the migrated schema.
That rules out dropping, renaming or tightening anything the previous release still reads or writes. See
"Database Migrations" in AGENTS.md for the expand/contract pattern.

A deliberate contract step, run only after a deploy whose code no longer uses the schema it removes, sets
`contract_step = "<what stopped using it, and the deploy that shipped that>"` on its Migration class.
"""

import re

from django.db import migrations
from django.db.migrations.loader import MigrationLoader
from django.db.migrations.state import ProjectState
from django.test import SimpleTestCase

# test_migration_safety.py grandfathers migrations that were applied in production before the rule existed.
APPLIED_BEFORE_THE_RULE = {("discover", "0002_popularfeed_subcategory")}

# test_migration_safety.py allows type changes where every value the old type held still fits.
WIDENING_TYPE_CHANGES = {
    ("CharField", "TextField"),
    ("SmallIntegerField", "IntegerField"),
    ("SmallIntegerField", "BigIntegerField"),
    ("IntegerField", "BigIntegerField"),
    ("PositiveSmallIntegerField", "PositiveIntegerField"),
    # Django's replacement for NullBooleanField is the same column; dropping null is caught as NOT NULL.
    ("NullBooleanField", "BooleanField"),
}

DESTRUCTIVE_SQL = re.compile(r"\b(drop|rename)\b|\bset\s+not\s+null\b", re.IGNORECASE)


def project_migration_nodes(loader):
    """(app_label, name) of every NewsBlur migration, parents before children."""
    plan = []
    seen = set()
    for leaf in sorted(loader.graph.leaf_nodes()):
        for node in loader.graph.forwards_plan(leaf):
            if node not in seen:
                seen.add(node)
                plan.append(node)
    return plan


def is_project_migration(migration):
    return type(migration).__module__.startswith("apps.")


def sql_text(sql):
    """RunSQL takes a string, or a list of strings and (sql, params) pairs."""
    if isinstance(sql, str):
        return sql
    return " ".join(statement if isinstance(statement, str) else statement[0] for statement in sql)


def describe_unsafe(operation, app_label, state, created_here=()):
    """Why previous-release code can't run against the schema after this operation, or None. Tables created
    in the same migration (created_here) are new to this release, so nothing older uses them yet."""
    if isinstance(operation, migrations.SeparateDatabaseAndState):
        problems = [
            describe_unsafe(inner, app_label, state, created_here) for inner in operation.database_operations
        ]
        return "; ".join(problem for problem in problems if problem) or None
    if isinstance(operation, migrations.RemoveField):
        return "drops %s.%s, which the previous release still selects" % (
            operation.model_name,
            operation.name,
        )
    if isinstance(operation, migrations.RenameField):
        return "renames %s.%s, which the previous release still selects" % (
            operation.model_name,
            operation.old_name,
        )
    if isinstance(operation, migrations.DeleteModel):
        return "drops the %s table" % operation.name
    if isinstance(operation, migrations.RenameModel):
        return "renames the %s table" % operation.old_name
    if isinstance(operation, migrations.AlterModelTable):
        return "renames the %s table" % operation.name
    model_key = getattr(operation, "model_name_lower", None) or getattr(operation, "name_lower", None)
    if model_key in created_here:
        return None
    if isinstance(operation, migrations.AddField):
        field = operation.field
        if not field.many_to_many and not field.null:
            # Django 3.1 drops the column default after adding it, so the previous release's inserts,
            # which omit the new column, fail its NOT NULL constraint.
            return "adds NOT NULL column %s.%s; add it with null=True" % (
                operation.model_name,
                operation.name,
            )
    if isinstance(operation, migrations.AlterField):
        model = state.models.get((app_label, operation.model_name_lower))
        previous = dict(model.fields).get(operation.name) if model else None
        field = operation.field
        column = "%s.%s" % (operation.model_name, operation.name)
        if previous is not None:
            if previous.null and not field.null:
                return "makes %s NOT NULL while the previous release may write NULL" % column
            if field.unique and not previous.unique:
                return "makes %s unique while the previous release may write duplicates" % column
            change = (type(previous).__name__, type(field).__name__)
            if change[0] != change[1] and change not in WIDENING_TYPE_CHANGES:
                return "changes %s from %s to %s, which the previous release's values may not fit" % (
                    column,
                    change[0],
                    change[1],
                )
            if previous.max_length and field.max_length and field.max_length < previous.max_length:
                return "shortens %s from %s to %s characters" % (
                    column,
                    previous.max_length,
                    field.max_length,
                )
    if isinstance(operation, migrations.AddConstraint):
        return "adds constraint %s, which the previous release may violate" % operation.constraint.name
    if isinstance(operation, migrations.AlterUniqueTogether):
        model = state.models.get((app_label, operation.name_lower))
        before = {tuple(fields) for fields in model.options.get("unique_together") or ()} if model else set()
        added = {tuple(fields) for fields in operation.unique_together or ()} - before
        if added:
            return "adds unique_together %s, which the previous release may violate" % sorted(added)
    if isinstance(operation, migrations.RunSQL) and DESTRUCTIVE_SQL.search(sql_text(operation.sql)):
        return "runs SQL that drops, renames or tightens schema"
    return None


def unsafe_migrations():
    """[(app_label, migration name, [reasons])] for project migrations the previous release can't survive."""
    loader = MigrationLoader(None, ignore_no_migrations=True)
    state = ProjectState(real_apps=list(loader.unmigrated_apps))
    found = []
    for app_label, name in project_migration_nodes(loader):
        migration = loader.graph.nodes[(app_label, name)]
        created_here = {
            operation.name_lower
            for operation in migration.operations
            if isinstance(operation, migrations.CreateModel)
        }
        reasons = []
        for operation in migration.operations:
            if is_project_migration(migration):
                reason = describe_unsafe(operation, app_label, state, created_here)
                if reason:
                    reasons.append(reason)
            operation.state_forwards(app_label, state)
        if reasons:
            found.append((app_label, name, reasons, getattr(migration, "contract_step", "")))
    return found


class Test_MigrationSafety(SimpleTestCase):
    def test_migrations_keep_the_previous_release_working(self):
        problems = []
        for app_label, name, reasons, contract_step in unsafe_migrations():
            if (app_label, name) in APPLIED_BEFORE_THE_RULE or contract_step.strip():
                continue
            problems.append("%s.%s: %s" % (app_label, name, "; ".join(reasons)))
        self.assertEqual(
            problems,
            [],
            "These migrations would break the release still running while a deploy migrates first. Make the "
            "change additive (see Database Migrations in AGENTS.md), or, for a cleanup after a deploy that "
            "stopped using the schema, set contract_step on the Migration explaining which deploy that was.",
        )

    def test_the_check_catches_what_breaks_old_code(self):
        from django.db import models

        state = ProjectState()
        state.add_model(
            migrations.state.ModelState(
                "profile",
                "Example",
                [
                    ("id", models.AutoField(primary_key=True)),
                    ("note", models.TextField(null=True)),
                    ("code", models.CharField(max_length=32, null=True)),
                    ("count", models.IntegerField(null=True)),
                ],
            )
        )
        unsafe = [
            migrations.RemoveField("example", "note"),
            migrations.RenameField("example", "note", "notes"),
            migrations.DeleteModel("Example"),
            migrations.AddField("example", "flag", models.BooleanField(default=False)),
            migrations.AlterField("example", "note", models.TextField(default="")),
            migrations.AlterField("example", "code", models.CharField(max_length=32, null=True, unique=True)),
            migrations.AlterField("example", "code", models.CharField(max_length=16, null=True)),
            migrations.AlterField("example", "count", models.CharField(max_length=10, null=True)),
            migrations.AddConstraint(
                "example", models.UniqueConstraint(fields=["code"], name="example_code")
            ),
            migrations.AddConstraint(
                "example", models.CheckConstraint(check=models.Q(count__gte=0), name="example_count")
            ),
            migrations.AlterUniqueTogether("example", {("code", "count")}),
            migrations.RunSQL("ALTER TABLE profile_example DROP COLUMN note"),
        ]
        safe = [
            migrations.AddField("example", "language", models.CharField(max_length=16, null=True)),
            migrations.AlterField("example", "note", models.TextField(null=True, blank=True)),
            migrations.AlterField("example", "code", models.CharField(max_length=64, null=True)),
            migrations.AlterField("example", "code", models.TextField(null=True)),
            migrations.AlterField("example", "count", models.BigIntegerField(null=True)),
            # An index only locks writes while it builds; AGENTS.md asks for AddIndexConcurrently on big tables.
            migrations.AddIndex("example", models.Index(fields=["code"], name="example_code_idx")),
            migrations.RunSQL("CREATE INDEX example_note ON profile_example (note)"),
        ]
        for operation in unsafe:
            self.assertTrue(describe_unsafe(operation, "profile", state), operation)
        for operation in safe:
            self.assertIsNone(describe_unsafe(operation, "profile", state), operation)
        # A table created in the same migration is new to this release.
        self.assertIsNone(describe_unsafe(unsafe[3], "profile", state, created_here={"example"}))
        self.assertIsNone(describe_unsafe(unsafe[10], "profile", state, created_here={"example"}))
