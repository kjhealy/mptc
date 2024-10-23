## MPTC deploy
PUBLIC_DIR='_site/'
SSH_USER='kjhealy@kjhealy.co'
DOCUMENT_ROOT='~/public/mptc.io/public_html'


echo "Setting permissions ..."
cp html/htaccess $PUBLIC_DIR/.htaccess

find $PUBLIC_DIR -type d -print0 | xargs -0 chmod 755
find $PUBLIC_DIR -type f -print0 | xargs -0 chmod 644

echo "Uploading changes to remote server..."
rsync --exclude='.DS_Store' -Prvzce 'ssh -p 22' $PUBLIC_DIR $SSH_USER:$DOCUMENT_ROOT --delete-after
