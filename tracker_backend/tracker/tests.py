from django.test import override_settings
from rest_framework import status
from rest_framework.test import APITestCase

from .models import TrackerData


@override_settings(DEVICE_API_KEY="test-device-key")
class TrackerApiTests(APITestCase):
    def location_payload(self, **overrides):
        payload = {
            "api_key": "test-device-key",
            "device_id": "SMART-GUARDIAN-001",
            "device_name": "Smart Guardian",
            "event_type": "LOCATION_UPDATE",
            "latitude": 0.332201,
            "longitude": 32.570472,
            "distance_metres": 4.2,
            "satellites": 9,
            "map_url": "https://maps.google.com/?q=0.332201,32.570472",
        }
        payload.update(overrides)
        return payload

    def test_device_can_post_real_location(self):
        response = self.client.post(
            "/api/location/",
            self.location_payload(),
            format="json",
        )

        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(TrackerData.objects.count(), 1)
        self.assertEqual(response.data["event_type"], "LOCATION_UPDATE")

    def test_location_post_rejects_bad_device_key(self):
        response = self.client.post(
            "/api/location/",
            self.location_payload(api_key="wrong-key"),
            format="json",
        )
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)

    def test_latest_endpoint_returns_newest_event(self):
        TrackerData.objects.create(
            event_type="LOCATION_UPDATE",
            latitude=0.1,
            longitude=32.1,
        )
        newest = TrackerData.objects.create(
            event_type="GEOFENCE_EXIT",
            latitude=0.2,
            longitude=32.2,
        )

        response = self.client.get("/api/location/latest/")

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data["id"], newest.id)
        self.assertTrue(response.data["emergency"])

    def test_config_stores_separate_guardian_and_device_numbers(self):
        response = self.client.patch(
            "/api/config/",
            {
                "guardian_phone": "+256700000001",
                "device_phone": "+256700000002",
                "geofence_latitude": 0.332201,
                "geofence_longitude": 32.570472,
                "geofence_radius_m": 100,
            },
            format="json",
        )

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data["guardian_phone"], "+256700000001")
        self.assertEqual(response.data["device_phone"], "+256700000002")
