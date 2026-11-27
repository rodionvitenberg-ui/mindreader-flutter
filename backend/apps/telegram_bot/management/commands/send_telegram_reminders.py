from django.core.management.base import BaseCommand

from apps.telegram_bot.service import dispatch_due_reminders


class Command(BaseCommand):
    help = "Dispatch due Tarot Tree Telegram reminders (Zeigarnik check-ins, daily card, lunar windows)."

    def handle(self, *args, **options):
        counts = dispatch_due_reminders()
        self.stdout.write(
            self.style.SUCCESS(
                f"Dispatched reminders: checkins={counts['checkins']}, "
                f"daily={counts['daily']}, lunar={counts['lunar']}"
            )
        )
