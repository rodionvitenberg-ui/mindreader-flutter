from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("accounts", "0003_account_password_auth"),
    ]

    operations = [
        migrations.AddField(
            model_name="principal",
            name="early_supporter_slot",
            field=models.PositiveSmallIntegerField(blank=True, null=True, unique=True),
        ),
        migrations.AddField(
            model_name="principal",
            name="is_pro",
            field=models.BooleanField(db_index=True, default=False),
        ),
        migrations.AddField(
            model_name="principal",
            name="pro_expires_at",
            field=models.DateTimeField(blank=True, db_index=True, null=True),
        ),
        migrations.AddField(
            model_name="principal",
            name="pro_plan",
            field=models.CharField(
                blank=True,
                choices=[
                    ("", "Free"),
                    ("early_monthly", "Early Supporter Monthly ($4.99/mo)"),
                    ("monthly", "Standard Monthly ($6.99/mo)"),
                    ("annual", "Early Supporter Annual ($39.99/yr)"),
                    ("lifetime", "Lifetime"),
                ],
                default="",
                max_length=24,
            ),
        ),
        migrations.AddField(
            model_name="principal",
            name="pro_since",
            field=models.DateTimeField(blank=True, null=True),
        ),
    ]
