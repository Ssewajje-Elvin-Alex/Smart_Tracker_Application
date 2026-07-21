from django.contrib import admin

from .models import DeviceConfig, TrackerData


@admin.register(TrackerData)
class TrackerDataAdmin(admin.ModelAdmin):
    list_display = (
        "device_id",
        "event_type",
        "latitude",
        "longitude",
        "timestamp",
    )
    list_filter = ("event_type", "device_id")
    ordering = ("-timestamp",)


@admin.register(DeviceConfig)
class DeviceConfigAdmin(admin.ModelAdmin):
    list_display = (
        "device_id",
        "guardian_phone",
        "device_phone",
        "geofence_radius_m",
        "updated_at",
    )
