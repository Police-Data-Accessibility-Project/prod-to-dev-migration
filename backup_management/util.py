from ObjectInfo import ObjectInfo


def get_least_recent_object(objects: list[ObjectInfo]) -> ObjectInfo:
    return min(objects, key=lambda o: o.last_modified)