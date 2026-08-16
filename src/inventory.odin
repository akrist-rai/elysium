package game

// Objects you are carrying. Clothing and tools bend skills up or down while
// worn, which is most of what equipment is for here -- there is nothing to
// fight, only things to be slightly better or worse at.
Item :: struct {
	id:          string,
	name:        string,
	description: string,
	equippable:  bool,
	equipped:    bool,
	modifiers:   []Skill_Modifier,
}

Inventory :: struct {
	items: [dynamic]Item,
}

inventory_init :: proc(inv: ^Inventory) {
	inv.items = make([dynamic]Item)
}

inventory_has :: proc(inv: ^Inventory, id: string) -> bool {
	for &it in inv.items {
		if it.id == id {
			return true
		}
	}
	return false
}

inventory_find :: proc(inv: ^Inventory, id: string) -> ^Item {
	for &it in inv.items {
		if it.id == id {
			return &it
		}
	}
	return nil
}

inventory_add :: proc(inv: ^Inventory, item: Item) {
	if inventory_has(inv, item.id) {
		return
	}
	append(&inv.items, item)
}

inventory_remove :: proc(inv: ^Inventory, id: string) {
	for i := 0; i < len(inv.items); i += 1 {
		if inv.items[i].id == id {
			ordered_remove(&inv.items, i)
			return
		}
	}
}

inventory_toggle_equip :: proc(inv: ^Inventory, id: string) {
	it := inventory_find(inv, id)
	if it == nil || !it.equippable {
		return
	}
	it.equipped = !it.equipped
}
