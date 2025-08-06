import { createBrowserRouter, Navigate } from 'react-router-dom';
import { Layout } from '../layout';
import { Home } from '../pages/Home';
import { Events } from '../pages/Events';
import { EventDetail, Marketplace, TokenSwap, Profile, CreateEvent } from '../pages';

export const router = createBrowserRouter([
  {
    path: '/',
    element: <Layout />,
    children: [
      {
        index: true,
        element: <Home />,
      },
      {
        path: 'events',
        element: <Events />,
      },
      {
        path: 'events/:eventId',
        element: <EventDetail />,
      },
      {
        path: 'marketplace',
        element: <Marketplace />,
      },
      {
        path: 'swap',
        element: <TokenSwap />,
      },
      {
        path: 'profile',
        element: <Profile />,
      },
      {
        path: 'create-event',
        element: <CreateEvent />,
      },
      {
        path: '*',
        element: <Navigate to="/" replace />,
      },
    ],
  },
]);

// 路由配置
export const routes = [
  {
    path: '/',
    name: '首页',
    icon: 'Home',
  },
  {
    path: '/events',
    name: '活动',
    icon: 'Calendar',
  },
  {
    path: '/marketplace',
    name: '市场',
    icon: 'ShoppingBag',
  },
  {
    path: '/swap',
    name: '交换',
    icon: 'ArrowLeftRight',
  },
  {
    path: '/profile',
    name: '个人',
    icon: 'User',
    requireAuth: true,
  },
] as const;
