from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("tracker", "0001_initial"),
    ]

    operations = [
        migrations.AddField(
            model_name="trackerdata",
            name="device_id",
            field=models.CharField(default="SMART-GUARDIAN-001", max_length=64),
        ),
        migrations.AddField(
            model_name="trackerdata",
            name="device_name",
            field=models.CharField(blank=True, default="", max_length=64),
        ),
        migrations.AddField(
            model_name="trackerdata",
            name="event_type",
            field=models.CharField(
                choices=[
                    ("EMERGENCY_BUTTON", "Emergency Button"),
                    ("GEOFENCE_EXIT", "Geofence Exit"),
                    ("GEOFENCE_RETURN", "Geofence Return"),
                    ("BACKEND_TEST", "Backend Test"),
                ],
                default="BACKEND_TEST",
                max_length=32,
            ),
        ),
        migrations.AddField(
            model_name="trackerdata",
            name="distance_metres",
            field=models.FloatField(blank=True, null=True),
        ),
        migrations.AddField(
            model_name="trackerdata",
            name="satellites",
            field=models.IntegerField(blank=True, null=True),
        ),
        migrations.AddField(
            model_name="trackerdata",
            name="map_url",
            field=models.URLField(blank=True, default="", max_length=255),
        ),
        migrations.RemoveField(
            model_name="trackerdata",
            name="emergency",
        ),
        migrations.AlterField(
            model_name="trackerdata",
            name="battery_level",
            field=models.IntegerField(default=100),
        ),
        migrations.AlterField(
            model_name="trackerdata",
            name="timestamp",
            field=models.DateTimeField(auto_now_add=True),
        ),
        migrations.AlterModelOptions(
            name="trackerdata",
            options={"ordering": ["-timestamp"]},
        ),
    ]
