from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [
        ("tracker", "0003_deviceconfig"),
    ]

    operations = [
        migrations.AddField(
            model_name="deviceconfig",
            name="device_phone",
            field=models.CharField(blank=True, default="", max_length=20),
        ),
        migrations.AlterField(
            model_name="trackerdata",
            name="event_type",
            field=models.CharField(
                choices=[
                    ("LOCATION_UPDATE", "Location Update"),
                    ("EMERGENCY_BUTTON", "Emergency Button"),
                    ("GEOFENCE_EXIT", "Geofence Exit"),
                    ("GEOFENCE_RETURN", "Geofence Return"),
                    ("BACKEND_TEST", "Backend Test"),
                ],
                default="LOCATION_UPDATE",
                max_length=32,
            ),
        ),
    ]
