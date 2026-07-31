[
  {
    title: "Kayıp Kervan",
    hook: "Boranda kaybolan tuz kervanının izi.",
    brief: "Akçabük köyünün kış tuzunu getiren kervan üç gündür kayıp. " \
           "Boran geçidi kapatmadan kervanı bulup köye ulaştırmak gerekiyor. " \
           "Rota: Akçabük'ten Boranlı Geçit'e; izler, terk edilmiş konaklar ve " \
           "geçitteki asma köprü üzerinden ilerler. Kervanın kaybı bir kaza da " \
           "olabilir, bir pusu da."
  },
  {
    title: "Gölün Sırrı",
    hook: "Suyun altında kalmış eski bir köy.",
    brief: "Kuraklıkta çekilen göl, yıllar önce sular altında kalmış bir köyü " \
           "ortaya çıkardı. Köyün terk edilme sebebi hiçbir kayıtta yok; gölden " \
           "geceleri çan sesi duyduğunu söyleyenler var. Sırrı çözmek için batık " \
           "köye inilmesi gerekiyor."
  }
].each do |attributes|
  Adventure.create_with(attributes).find_or_create_by!(title: attributes[:title])
end
