CONIGLIO Luigi
CONSTANS Victor

########	Compression et décompression avec l'algorithme LZ77	##########

### Encodage des triplets

L'encodage du triplet dans le fichier compressé se fait de la manière suivante:(l,c,p).
l: longueur de la répétition
c: le caractère suivant
p: distance entre le début du tampon de lecture et le début de la répétition
l et c sont tous les deux codé sur un octet, p en revanche est codé soit sur un octet, soit sur deux soit sur 4. Cela permet d'avoir un tampon de recherche de très grande taille et d'augementer les chance de trouver une répétition. Le nombre d'octet alloué à p est déduite en fonction de la taille du tampon de recherche que l'utilisateur à défini. Si le tampon de recherche à une taille inférieur ou égale à 255, p sera sur un octet. Si la taille est  supérieur à 255 et inférieur ou égale à 65535 alors p sera codé sur 2 octets. Et si la taille est supérieur à 65535 et inférieur ou égale à 4294967295 alors p sera codé sur 4 octets. Cela permet de choisir dynamiquement la meilleur taille pour codé p et ainsi d'économiser de la place pour obtenir une compression maximale.
Le triplet peux donc avoir des tailles différente en fonction de la taille de p. Il peux être encodé sur 3, 4 ou 6 octet selon la taille du tampon de recherche.

### Noms des fichiers

Le programme de compression prend en entrée n'importe quel nom de fichier et créé un fichier avec le même nom plus le suffixe ".lz77".
Par exemple, lors de la compression du fichier "Lepetitprince txt" on aura en sortie un fichier "Lepetitprince.txt.lz77". Si un fichier avec ce nom est déjà présent dans le dossier d'exécution il sera effacé et substitué par le nouveau.
Le programme de décompression n'accepte que des fichiers avec comme suffixe ".lz77" et créé un fichier avec le même nom sans ce suffixe.
Par exemple, lors de la compression du fichier "Lepetitprince.txt.lz77" on aura un fichier décompressé nommé "Lepetitprinceetxt". Si un fichier avec ce nom est déjà présent dans le dossier d'exécution il sera effacé et substitué par le nouveau.


### Questions

Les taux de compression ne sont pas les mêmes pour les différents fichiers qui sont compressés. Il va dépendre du contenu du fichier et surtout des répétitions qui sont présentes. Par exemple dans un fichier texte, plus il y aura de répétition meilleure sera la compression. On peut voir cela avec la compression des fichiers Lepetitprince.txt et Pirouette.txt qui contienne beaucoup de répétition de phrase; une phrase étant une répétition longue cela se traduira par une compression maximale.
En revanche il peut y avoir un taux de compression négatif (fichier compressé plus volumineux que le fichier original). C'est le cas par exemple du fichier Voltaire.txt qui contient peu de répétition et donc obtient un mauvais taux de compression.
Les valeurs de N et de F ont une influence sur le taux compression. En effet plus la valeur de N est grande meilleure sera la compression car le tampon de recherche et de lecture seront plus grand et cela améliorera la probabilité de trouver une répétition (qui pourrait être de grande taille). En revanche avoir une valeur de F trop grande est inutile, en effet, cela va réduire la taille du tampon de recherche et mieux vaut que celui-ci soit grand, on aura ainsi plus de chance de trouver une répétition car il contient plus de données.
L'algorithme lz77 possèdent un point fort: son grand potentiel de compression sur un fichier qui est répétitif.
En revanche l'algorithme est très mauvais lorsqu'il compresse un fichier qui ne contient pas ou très peu de répétitions. Prenon par exemple le pire des cas où un fichier ne contient que des caractère différents. L'algorithme ne trouvera jamais de répétitions, et encodera un caractère (un octet) avec minimum 3 octet. Il y a donc une multiplication par 3 du point du fichier original.
Un autre point faible est le temps d'exécution. En effet, avec un grand tampon de recherche, le programme va devoir parcourir tout ce tampon pour trouver des répétition. Cela peut être très long pour un grand tampon (>1000) qui contient beaucoup de fois le caractère recherché. De plus, si le caractère recherche est trouvé dans le tampon de recherche,il faut ensuite calculer la longeur de la répétition ce qui va encore rallongé le temps d'exécution. L'algorithme peux devenir très lent et mettre beaucoup de temps pour compresser un fichier.

