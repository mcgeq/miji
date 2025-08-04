pub trait Crud<T: Clone> {
    fn table_name() -> &'static str;
    fn primary_key() -> &'static str {
        "serial_num"
    }

    fn list(&self) -> Vec<T> {
        vec![]
    }

    fn list_paged(&self) -> Vec<T> {
        vec![]
    }

    fn get_by_serial_num(&self, serial_num: String) -> Option<T> {
        if serial_num.is_empty() {
            todo!();
        }
        None
    }
    
    fn create(&self, item: &T) -> T {
        item.clone()
    }

    fn update(&self, item: &T) -> T {
        item.clone()
    }

    fn delete(&self, serial_num: String) -> bool {
        if serial_num.is_empty() {
            return false;
        }
        true
    }

    fn count(&self) -> u64 {
        0
    }
}
