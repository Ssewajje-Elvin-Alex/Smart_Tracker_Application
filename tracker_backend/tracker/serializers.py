from rest_framework import serializers
from .models import TrackerData

class TrackerDataSerializer(serializers.ModelSerializer):
    class Meta:
        model = TrackerData
        fields = '__all__'