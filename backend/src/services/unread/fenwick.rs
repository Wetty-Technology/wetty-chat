#[derive(Debug, Clone)]
pub(super) struct FenwickTree {
    tree: Vec<i64>,
}

impl FenwickTree {
    pub(super) fn from_values(values: &[i64]) -> Self {
        let mut tree = Self {
            tree: vec![0; values.len() + 1],
        };
        for (index, value) in values.iter().enumerate() {
            tree.add(index, *value);
        }
        tree
    }

    pub(super) fn add(&mut self, index: usize, delta: i64) {
        let mut cursor = index + 1;
        while cursor < self.tree.len() {
            self.tree[cursor] += delta;
            cursor += cursor & cursor.wrapping_neg();
        }
    }

    pub(super) fn push(&mut self, value: i64) {
        let new_one_based_index = self.tree.len();
        let range_start_len =
            new_one_based_index - (new_one_based_index & new_one_based_index.wrapping_neg());
        let prior_range_sum = self.prefix_sum(self.len()) - self.prefix_sum(range_start_len);
        self.tree.push(prior_range_sum + value);
    }

    pub(super) fn prefix_sum(&self, len: usize) -> i64 {
        let mut cursor = len.min(self.len());
        let mut sum = 0;
        while cursor > 0 {
            sum += self.tree[cursor];
            cursor &= cursor - 1;
        }
        sum
    }

    pub(super) fn total(&self) -> i64 {
        self.prefix_sum(self.len())
    }

    fn len(&self) -> usize {
        self.tree.len().saturating_sub(1)
    }
}

#[cfg(test)]
mod tests {
    use super::FenwickTree;

    #[test]
    fn prefix_sums_use_dense_one_based_boundaries() {
        let tree = FenwickTree::from_values(&[1, 0, 1, 1]);

        assert_eq!(tree.prefix_sum(0), 0);
        assert_eq!(tree.prefix_sum(1), 1);
        assert_eq!(tree.prefix_sum(2), 1);
        assert_eq!(tree.prefix_sum(3), 2);
        assert_eq!(tree.prefix_sum(4), 3);
        assert_eq!(tree.total(), 3);
    }

    #[test]
    fn point_updates_adjust_later_prefixes_only() {
        let mut tree = FenwickTree::from_values(&[1, 0, 1, 1]);

        tree.add(1, 1);
        assert_eq!(tree.prefix_sum(1), 1);
        assert_eq!(tree.prefix_sum(2), 2);
        assert_eq!(tree.total(), 4);

        tree.add(2, -1);
        assert_eq!(tree.prefix_sum(2), 2);
        assert_eq!(tree.prefix_sum(3), 2);
        assert_eq!(tree.total(), 3);
    }

    #[test]
    fn push_extends_tree_without_rebuilding() {
        let mut tree = FenwickTree::from_values(&[1, 0, 1]);

        tree.push(1);
        assert_eq!(tree.prefix_sum(3), 2);
        assert_eq!(tree.prefix_sum(4), 3);

        tree.add(0, -1);
        assert_eq!(tree.prefix_sum(1), 0);
        assert_eq!(tree.prefix_sum(4), 2);
    }
}
