import type { Router } from 'framework7/types';

import NotFoundPage from '@/pages/404';
import ChatsPage from '@/pages/chats';

const routes: Router.RouteParameters[] = [
  {
    path: '/',
    component: ChatsPage,
  },
  {
    path: '/chats/',
    component: ChatsPage,
  },
  {
    path: '(.*)',
    component: NotFoundPage,
  },
];

export default routes;
