from django.contrib import admin

from .models import Personality


@admin.register(Personality)
class PersonalityAdmin(admin.ModelAdmin):
    list_display = ("slug", "name", "enabled", "language", "provider")
    list_filter = ("enabled",)
    prepopulated_fields = {"slug": ("name",)}
    search_fields = ("slug", "name")
