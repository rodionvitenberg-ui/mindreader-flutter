from django.db import migrations, models


def cleanup_moved_store_promos(apps_registry, schema_editor):
    DeckPromo = apps_registry.get_model("catalog", "DeckPromo")
    DeckPromo.objects.filter(deck__isnull=True, system="tarot", pack_id="soimoi", image="").delete()
    DeckPromo.objects.filter(deck__isnull=True, system="runes", pack_id="charred_birch", image="").delete()


def backfill_item_types(apps_registry, schema_editor):
    Deck = apps_registry.get_model("catalog", "Deck")
    mapping = {"tarot": "tarot_deck", "lenormand": "lenormand_deck", "runes": "rune_set"}
    for deck in Deck.objects.all():
        if not deck.item_type:
            deck.item_type = mapping.get(deck.system, "tarot_deck")
            deck.save(update_fields=["item_type"])


class Migration(migrations.Migration):

    dependencies = [
        ("catalog", "0003_extra_rune_promos"),
    ]

    operations = [
        migrations.AddField(
            model_name="deck",
            name="badge",
            field=models.CharField(blank=True, max_length=32),
        ),
        migrations.AddField(
            model_name="deck",
            name="featured",
            field=models.BooleanField(default=False),
        ),
        migrations.AddField(
            model_name="deck",
            name="item_type",
            field=models.CharField(
                blank=True,
                choices=[
                    ("tarot_deck", "Tarot deck"),
                    ("lenormand_deck", "Lenormand deck"),
                    ("rune_set", "Rune set"),
                    ("card_back", "Card back"),
                    ("table_theme", "Table theme"),
                    ("spread_pack", "Spread pack"),
                    ("bundle", "Bundle"),
                ],
                default="",
                max_length=24,
            ),
        ),
        migrations.AddField(
            model_name="deck",
            name="sort_order",
            field=models.IntegerField(default=100),
        ),
        migrations.AddField(
            model_name="deck",
            name="tagline",
            field=models.CharField(blank=True, max_length=200),
        ),
        migrations.AddField(
            model_name="deck",
            name="visual_config",
            field=models.JSONField(blank=True, default=dict),
        ),
        migrations.AlterModelOptions(
            name="deck",
            options={"ordering": ("-featured", "sort_order", "title", "id")},
        ),
        migrations.AlterField(
            model_name="deckasset",
            name="kind",
            field=models.CharField(
                choices=[
                    ("cover", "Cover"),
                    ("preview", "Preview"),
                    ("card", "Card"),
                    ("back", "Back"),
                    ("stone", "Stone"),
                ],
                max_length=8,
            ),
        ),
        migrations.RunPython(cleanup_moved_store_promos, migrations.RunPython.noop),
        migrations.RunPython(backfill_item_types, migrations.RunPython.noop),
    ]
