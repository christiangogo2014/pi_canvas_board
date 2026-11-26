import { createConsumer } from '@rails/actioncable'

// ActionCable consumer for live board refresh notifications.
let consumer

export function subscribeToBoard(projectDir, onRefresh) {
  if (!consumer) consumer = createConsumer('/cable')
  const subscription = consumer.subscriptions.create(
    { channel: 'BoardChannel', project_dir: projectDir },
    {
      received: (msg) => {
        if (msg?.event === 'refresh') onRefresh()
      },
    }
  )
  // Return an unsubscribe handle
  return () => consumer.subscriptions.remove(subscription)
}
