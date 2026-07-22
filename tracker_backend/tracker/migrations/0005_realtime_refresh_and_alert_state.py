from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [
        ("tracker", "0004_device_phone_and_location_update"),
    ]

    operations = [
        migrations.AddField(
            model_name="deviceconfig",
            name="location_request_at",
            field=models.DateTimeField(blank=True, null=True),
        ),
        migrations.AddField(
            model_name="deviceconfig",
            name="location_request_id",
            field=models.PositiveBigIntegerField(default=0),
        ),
        migrations.AddField(
            model_name="deviceconfig",
            name="location_request_pending",
            field=models.BooleanField(default=False),
        ),
        migrations.AddField(
            model_name="trackerdata",
            name="emergency_active",
            field=models.BooleanField(default=False),
        ),
        migrations.AddField(
            model_name="trackerdata",
            name="geofence_outside",
            field=models.BooleanField(default=False),
        ),
        migrations.AddField(
            model_name="trackerdata",
            name="location_request_id",
            field=models.PositiveBigIntegerField(blank=True, null=True),
        ),
    ]
