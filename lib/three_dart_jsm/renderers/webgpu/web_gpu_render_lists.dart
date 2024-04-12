part of three_webgpu;

int painterSortStable(RenderItem a, RenderItem b) {
  if (a.groupOrder != b.groupOrder) {
    return a.groupOrder - b.groupOrder;
  } else if (a.renderOrder != b.renderOrder) {
    return a.renderOrder - b.renderOrder;
  } else if (a.material.id != b.material.id) {
    return a.material.id - b.material.id;
  } else if (a.z != b.z) {
    return a.z - b.z;
  } else {
    return a.id - b.id;
  }
}

int reversePainterSortStable(RenderItem a, RenderItem b) {
  if (a.groupOrder != b.groupOrder) {
    return a.groupOrder - b.groupOrder;
  } else if (a.renderOrder != b.renderOrder) {
    return a.renderOrder - b.renderOrder;
  } else if (a.z != b.z) {
    return b.z - a.z;
  } else {
    return a.id - b.id;
  }
}

class WebGPURenderList {
  late List renderItems;
  late int renderItemsIndex;
  late List opaque;
  late List transparent;

  WebGPURenderList() {
    this.renderItems = [];
    this.renderItemsIndex = 0;

    this.opaque = [];
    this.transparent = [];
  }

  void init() {
    this.renderItemsIndex = 0;

    this.opaque.length = 0;
    this.transparent.length = 0;
  }

  RenderItem? getNextRenderItem(Object3D object, BufferGeometry geometry, Material material, int groupOrder, z, int group) {
    RenderItem? renderItem = null;

    if (this.renderItemsIndex < this.renderItems.length) {
      renderItem = this.renderItems[this.renderItemsIndex];
    }

    if (renderItem == null) {
      renderItem = RenderItem(
          id: object.id,
          object: object,
          geometry: geometry,
          material: material,
          groupOrder: groupOrder,
          renderOrder: object.renderOrder,
          z: z,
          group: group);

      // this.renderItems[ this.renderItemsIndex ] = renderItem;
      this.renderItems.add(renderItem);
    } 
    else {
      renderItem.id = object.id;
      renderItem.object = object;
      renderItem.geometry = geometry;
      renderItem.material = material;
      renderItem.groupOrder = groupOrder;
      renderItem.renderOrder = object.renderOrder;
      renderItem.z = z;
      renderItem.group = group;
    }

    this.renderItemsIndex++;

    return renderItem;
  }

  void push(Object3D object, BufferGeometry geometry, Material material, int groupOrder, z, int group) {
    final renderItem = this
        .getNextRenderItem(object, geometry, material, groupOrder, z, group);

    (material.transparent == true ? this.transparent : this.opaque)
        .add(renderItem);
  }

  void unshift(Object3D object, BufferGeometry geometry, Material material, int groupOrder, z, int group) {
    final renderItem = this
        .getNextRenderItem(object, geometry, material, groupOrder, z, group);

    (material.transparent == true ? this.transparent : this.opaque)
        .insert(0, renderItem);
  }

  void sort(customOpaqueSort,customTransparentSort) {
    if (this.opaque.length > 1)
      this.opaque.sort(customOpaqueSort ?? painterSortStable);
    if (this.transparent.length > 1)
      this.transparent.sort(customTransparentSort ?? reversePainterSortStable);
  }

  void finish() {
    // Clear references from inactive renderItems in the list

    for (int i = this.renderItemsIndex, il = this.renderItems.length; i < il;i++) {
      final renderItem = this.renderItems[i];

      if (renderItem.id == null) break;

      renderItem.id = null;
      renderItem.object = null;
      renderItem.geometry = null;
      renderItem.material = null;
      renderItem.program = null;
      renderItem.group = null;
    }
  }
}

class WebGPURenderLists {
  late WeakMap lists;

  WebGPURenderLists() {
    this.lists = new WeakMap();
  }

  get(Scene scene,Camera camera) {
    final lists = this.lists;

    final cameras = lists.get(scene);
    WebGPURenderList? list;

    if (cameras == null) {
      list = new WebGPURenderList();
      lists.set(scene, new WeakMap());
      lists.get(scene).set(camera, list);
    } else {
      list = cameras.get(camera);
      if (list == null) {
        list = WebGPURenderList();
        cameras.set(camera, list);
      }
    }

    return list;
  }

  void dispose() {
    this.lists = new WeakMap();
  }
}

class RenderItem {
  int id;
  Object3D object;
  BufferGeometry geometry;
  Material material;
  int groupOrder;
  int renderOrder;
  dynamic z;
  int group;

  RenderItem({
    required this.id,
    required this.object,
    required this.geometry,
    required this.material,
    required this.groupOrder,
    required this.renderOrder,
    required this.z,
    required this.group
  });
}
