export const fetchRemoteSettings = createAsyncThunk('settings/fetchRemoteSettings', async (_, { dispatch }) => {
  const { usersApi } = await import('@/api/users');
  const prefs = await usersApi.getUserSettings();
  dispatch(replaceSettings(prefs));
});
