import apps.catalog.models
import django.db.models.deletion
import uuid
from django.db import migrations, models


def seed_builtin_promos(apps_registry, schema_editor):
    DeckPromo = apps_registry.get_model("catalog", "DeckPromo")
    for system, pack_id, title in apps.catalog.models.BUILTIN_PROMO_PACKS:
        DeckPromo.objects.get_or_create(
            system=system,
            pack_id=pack_id,
            defaults={"title": title},
        )


class Migration(migrations.Migration):

    dependencies = [
        ("catalog", "0001_initial"),
    ]

    operations = [
        migrations.CreateModel(
            name="DeckPromo",
            fields=[
                ("id", models.UUIDField(default=uuid.uuid4, editable=False, primary_key=True, serialize=False)),
                ("system", models.CharField(choices=[("tarot", "Tarot"), ("lenormand", "Lenormand"), ("runes", "Runes")], max_length=10)),
                ("pack_id", models.SlugField(max_length=80)),
                ("title", models.CharField(blank=True, max_length=180)),
                ("image", models.FileField(blank=True, storage=apps.catalog.models.promo_storage, upload_to=apps.catalog.models.promo_path)),
                ("sha256", models.CharField(blank=True, editable=False, max_length=64)),
                ("updated_at", models.DateTimeField(auto_now=True)),
                ("deck", models.OneToOneField(blank=True, null=True, on_delete=django.db.models.deletion.CASCADE, related_name="promo", to="catalog.deck")),
            ],
            options={
                "ordering": ("system", "pack_id"),
                "constraints": [
                    models.UniqueConstraint(fields=("system", "pack_id"), name="unique_deck_promo_pack"),
                ],
            },
        ),
        migrations.RunPython(seed_builtin_promos, migrations.RunPython.noop),
    ]
