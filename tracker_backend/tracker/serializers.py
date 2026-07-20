from rest_framework import serializers
from .models import TrackerData


class TrackerDataSerializer(serializers.ModelSerializer):
    # Computed from event_type, not stored directly — exposed for the app.
    emergency = serializers.BooleanField(read_only=True)

    class Meta:
        model = TrackerData
        fields = [
            "id",
            "device_id",
            "device_name",
            "event_type",
            "latitude",
            "longitude",
            "distance_metres",
            "satellites",
            "map_url",
            "battery_level",
            "emergency",
            "timestamp",
        ]
        read_only_fields = ["id", "timestamp"]
