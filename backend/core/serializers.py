from rest_framework import serializers

from .utils import camelize


class CamelCaseSerializer(serializers.Serializer):
    def to_representation(self, instance):
        return camelize(super().to_representation(instance))


class CamelCaseModelSerializer(serializers.ModelSerializer):
    def to_representation(self, instance):
        return camelize(super().to_representation(instance))
