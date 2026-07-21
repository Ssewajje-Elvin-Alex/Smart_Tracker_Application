from rest_framework import serializers

from .models import DeviceConfig, TrackerData


class TrackerDataSerializer(serializers.ModelSerializer):
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


class DeviceConfigSerializer(serializers.ModelSerializer):
    class Meta:
        model = DeviceConfig
        fields = [
            "device_id",
            "guardian_phone",
            "device_phone",
            "geofence_latitude",
            "geofence_longitude",
            "geofence_radius_m",
            "updated_at",
        ]
        read_only_fields = ["updated_at"]

    def validate_geofence_radius_m(self, value):
        if value < 10 or value > 100000:
            raise serializers.ValidationError(
                "Radius must be from 10 to 100000 metres."
            )
        return value
