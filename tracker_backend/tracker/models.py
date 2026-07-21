from django.db import models

EVENT_TYPE_CHOICES = [
    ("LOCATION_UPDATE", "Location Update"),
    ("EMERGENCY_BUTTON", "Emergency Button"),
    ("GEOFENCE_EXIT", "Geofence Exit"),
    ("GEOFENCE_RETURN", "Geofence Return"),
    ("BACKEND_TEST", "Backend Test"),
]

# Event types that should flip the app into "EMERGENCY" state.
EMERGENCY_EVENT_TYPES = {"EMERGENCY_BUTTON", "GEOFENCE_EXIT"}


class TrackerData(models.Model):
    device_id = models.CharField(max_length=64, default="SMART-GUARDIAN-001")
    device_name = models.CharField(max_length=64, blank=True, default="")

    event_type = models.CharField(
        max_length=32,
        choices=EVENT_TYPE_CHOICES,
        default="LOCATION_UPDATE",
    )

    latitude = models.FloatField()
    longitude = models.FloatField()
    distance_metres = models.FloatField(null=True, blank=True)
    satellites = models.IntegerField(null=True, blank=True)
    map_url = models.URLField(max_length=255, blank=True, default="")
    battery_level = models.IntegerField(default=100)
    timestamp = models.DateTimeField(auto_now_add=True)

    @property
    def emergency(self) -> bool:
        return self.event_type in EMERGENCY_EVENT_TYPES

    def __str__(self):
        return (
            f"{self.device_id} [{self.event_type}] "
            f"({self.latitude}, {self.longitude})"
        )

    class Meta:
        ordering = ["-timestamp"]


class DeviceConfig(models.Model):
    """Guardian-editable settings for one Smart Guardian device."""

    device_id = models.CharField(
        max_length=64,
        unique=True,
        default="SMART-GUARDIAN-001",
    )

    # Destination for direct emergency/geofence SMS alerts.
    guardian_phone = models.CharField(max_length=20, blank=True, default="")

    # SIM card installed in the SIM800L. The Flutter Listen Live button calls it.
    device_phone = models.CharField(max_length=20, blank=True, default="")

    geofence_latitude = models.FloatField(default=0.0)
    geofence_longitude = models.FloatField(default=0.0)
    geofence_radius_m = models.FloatField(default=500.0)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"Config for {self.device_id}"
