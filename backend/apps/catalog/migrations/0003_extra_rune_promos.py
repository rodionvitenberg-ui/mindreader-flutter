from django.db import migrations


EXTRA_RUNE_PROMOS = (
    ("runes", "moss_agate", "Forest Moss Agate & Silver"),
    ("runes", "charred_birch", "Charred Nordic Birch & Frost"),
)


def seed_extra_rune_promos(apps_registry, schema_editor):
    DeckPromo = apps_registry.get_model("catalog", "DeckPromo")
    for system, pack_id, title in EXTRA_RUNE_PROMOS:
        DeckPromo.objects.get_or_create(
            system=system,
            pack_id=pack_id,
            defaults={"title": title},
        )


class Migration(migrations.Migration):

    dependencies = [
        ("catalog", "0002_deck_promo"),
    ]

    operations = [
        migrations.RunPython(seed_extra_rune_promos, migrations.RunPython.noop),
    ]
