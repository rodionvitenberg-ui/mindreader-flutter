from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("accounts", "0002_handoff_token"),
    ]

    operations = [
        migrations.AddField(
            model_name="principal",
            name="display_name",
            field=models.CharField(blank=True, default="", max_length=120),
        ),
        migrations.AddField(
            model_name="principal",
            name="email_confirmed",
            field=models.BooleanField(default=False),
        ),
    ]
