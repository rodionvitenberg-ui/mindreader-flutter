from django.db import migrations


def default_personality(apps, schema_editor):
    apps.get_model("oracle", "Personality").objects.get_or_create(
        slug="default",
        defaults={
            "name": "Tarot Tree Oracle",
            "description": "Reflective, grounded readings.",
            "system_prompt": "You are the Tarot Tree Oracle. Interpret the supplied cards and positions "
                             "symbolically. Do not invent cards or private facts. Avoid categorical medical, "
                             "legal, financial or future predictions. Use the supplied language and context.",
            "style": "Calm, concise and reflective.",
            "language": "Reply in the reader's language.",
        },
    )


class Migration(migrations.Migration):
    dependencies = [("oracle", "0001_initial")]
    operations = [migrations.RunPython(default_personality, migrations.RunPython.noop)]
